% Observation Model for 12 Dof Quadrotor with radio beacon based observations 
% The beacons can be anywhere in 3D space.
% Euler angles (ZYZ convention) are used to represent the orientation of the robot

classdef Landmarks_3D_EulerAngles < ObservationModel_interface
    % Note that because the class is defined as a handle class, the
    % properties must be defined such that they are do not change from an
    % object to another one.
    properties (Constant = true) % Note that you cannot change the order of the definition of properties in this class due to its structure (due to dependency between properties.)
        tmp_prop = Landmarks_3D_EulerAngles.costant_property_constructor();  % I use this technique to initialize the costant properties in run-time. If I can find a better way to do it, I will update it, as it seems a little bit strange.
        landmarks = Landmarks_3D_EulerAngles.tmp_prop.landmarks;
        obsDim = Landmarks_3D_EulerAngles.tmp_prop.obsDim;
        obsNoiseDim = Landmarks_3D_EulerAngles.obsDim; % observation noise dimension. In some other observation models the noise dimension may be different from the observation dimension.
        zeroNoise = zeros(Landmarks_3D_EulerAngles.obsNoiseDim,1); % zero observation noise
        eta = user_data_class.par.observation_model_parameters.eta; 
        sigma_b = user_data_class.par.observation_model_parameters.sigma_b;
    end
    properties
       plot_handle;
    end
    
    methods (Static = true)
        function temporary_props = costant_property_constructor()
            LoadFileName = user_data_class.par.LoadFileName;
            SaveFileName = user_data_class.par.SaveFileName;
            Man_L = user_data_class.par.observation_model_parameters.interactive_OM;
            if Man_L == 0
                load(LoadFileName,'Landmarks')
                temporary_props.landmarks = Landmarks; %#ok<NODEF>
                temporary_props.landmarks(3,:) = 0; % Z coordinate is 0
                temporary_props.obsDim =  3*size(Landmarks,2);
            else
                temporary_props = Landmarks_3D_EulerAngles.request_landmarks();
            end
            Landmarks = temporary_props.landmarks; %#ok<NASGU>
            save(SaveFileName,'Landmarks','-append') % here, we save the landmarks for the future runs.
        end
        function temporary_props = request_landmarks()
            old_prop = Landmarks_3D_EulerAngles.set_figure();
            i=0;
            title({'Please mark Landmarks'},'fontsize',14)
            while true
                i=i+1;
                [Lx_temp,Ly_temp]=ginput(1);
                if isempty(Lx_temp) && i<3
                    title({'You have to choose at least 3 landmarks to have an observable system'},'fontsize',14)
                    i=i-1;
                    continue
                elseif isempty(Lx_temp) && i>=3
                    break
                else
                    Lx(i)=Lx_temp; %#ok<AGROW>
                    Ly(i)=Ly_temp; %#ok<AGROW>
                    temporary_props.plot_handle(i)=plot(Lx(i),Ly(i),'kp','markerfacecolor','k','markersize',12);
                end
            end
            Landmarks=[Lx;Ly;zeros(1,size(Lx,2))];
            temporary_props.landmarks = Landmarks;
            temporary_props.obsDim = 3*size(Landmarks,2);
            Landmarks_3D_EulerAngles.reset_figure(old_prop);
            title([])
        end
        
        function z = h_func(x,v)
            error('not implemented yet')
            L=Landmarks_3D_EulerAngles.landmarks;
            od = Landmarks_3D_EulerAngles.obsDim;
            N_L=size(L,2);
                        
            d=L-repmat(x(1:3),1,N_L);
            
            z(1:3:od-2,1) = sqrt(d(1,:).^2+d(2,:).^2+d(3,:).^2)'+v(1:3:od-2,1);
            
            angles = x(4:6);
            R = eul2r(angles');  % The "eul2r" is a function Peter Corke's Robotic Toolbox. The function accepts "row vector".

            d_body = R*d; % rotate the relative vectors to body frame;
            
            z(2:3:od-1,1) = atan2(d_body(2,:),d_body(1,:))' + v(2:3:od-1,1); % Azimuth
             
            z(3:3:od,1) = atan2(d_body(3,:),d_body(1,:))' + v(3:3:od,1); % Elevation
            
        end
        
        function H = dh_dx_func(x,v) %#ok<INUSD>
            error('not implemented yet')
            L = Landmarks_3D_EulerAngles.landmarks;
            od = Landmarks_3D_EulerAngles.obsDim;
            H = nan(od,state.dim); % memory preallocation
            
            q = [x(4) x(5) x(6) x(7)];
            q0 = q(1);
            q1 = q(2);
            q2 = q(3);
            q3 = q(4);
            
            R = quat2dcm(q) ; % R rotates from inertial to body frame
            
            dR_by_dq0 = 2*[q0,q3,-q2;-q3,q0,q1;q2,-q1,q0];
            
            dR_by_dq1 = 2*[q1,q2,q3;q2,-q1,q0;q3,-q0,-q1];
            
            dR_by_dq2 = 2*[-q2,q1,-q0;q1,q2,q3;q0,q3,-q2];
            
            dR_by_dq3 = 2*[-q3,q0,q1;-q0,-q3,q2;q1,q2,q3];
            
            for i=1:size(L,2)
                d_ig = L(:,i)- x(1:3); % displacement between robot and landmark in ground frame
                d_ib = R*d_ig ; % displacement in body frame
                r_i = norm(d_ig); % scalar distance between landmark 'i' and robot
                
                temp1 = 1 / ( (d_ib(1))^2 + (d_ib(2))^2 );
                temp2 =  1 / ( (d_ib(1))^2 + (d_ib(3))^2 );
                
                if temp1 > 1 | temp2 > 1
                    disp(['Range to Li :',num2str(r_i), '  Temp1 is : ',num2str(temp1),'   Temp2 is : ',  num2str(temp2)]);
                    disp(['d_ib x:', num2str(d_ib(1)), 'y :', num2str(d_ib(2)), ' z :', num2str(d_ib(3))]);
                    
                    H(3*i-2:3*i,:) = zeros(3,7);
                else
                    
                    Hi_11 = -d_ig(1) / r_i;
                    Hi_12 = -d_ig(2) / r_i;
                    Hi_13 = -d_ig(3) / r_i;
                    Hi_14 = 0;
                    Hi_15 = 0;
                    Hi_16 = 0;
                    Hi_17 = 0;
                    
                    dx_ib_dx = -R(1,1);
                    dx_ib_dy = -R(1,2);
                    dx_ib_dz = -R(1,3);
                    
                    dy_ib_dx = -R(2,1);
                    dy_ib_dy = -R(2,2);
                    dy_ib_dz = -R(2,3);
                    
                    dz_ib_dx = -R(3,1);
                    dz_ib_dy = -R(3,2);
                    dz_ib_dz = -R(3,3);
                    
                    dx_ib_by_dq0 = dR_by_dq0(1,1)*d_ig(1) + dR_by_dq0(1,2)*d_ig(2) + dR_by_dq0(1,3)*d_ig(3);
                    dx_ib_by_dq1 = dR_by_dq1(1,1)*d_ig(1) + dR_by_dq1(1,2)*d_ig(2) + dR_by_dq1(1,3)*d_ig(3);
                    dx_ib_by_dq2 = dR_by_dq2(1,1)*d_ig(1) + dR_by_dq2(1,2)*d_ig(2) + dR_by_dq2(1,3)*d_ig(3);
                    dx_ib_by_dq3 = dR_by_dq3(1,1)*d_ig(1) + dR_by_dq3(1,2)*d_ig(2) + dR_by_dq3(1,3)*d_ig(3);
                    
                    dy_ib_by_dq0 = dR_by_dq0(2,1)*d_ig(1) + dR_by_dq0(2,2)*d_ig(2) + dR_by_dq0(2,3)*d_ig(3);
                    dy_ib_by_dq1 = dR_by_dq1(2,1)*d_ig(1) + dR_by_dq1(2,2)*d_ig(2) + dR_by_dq1(2,3)*d_ig(3);
                    dy_ib_by_dq2 = dR_by_dq2(2,1)*d_ig(1) + dR_by_dq2(2,2)*d_ig(2) + dR_by_dq2(2,3)*d_ig(3);
                    dy_ib_by_dq3 = dR_by_dq3(2,1)*d_ig(1) + dR_by_dq3(2,2)*d_ig(2) + dR_by_dq3(2,3)*d_ig(3);
                    
                    dz_ib_by_dq0 = dR_by_dq0(3,1)*d_ig(1) + dR_by_dq0(3,2)*d_ig(2) + dR_by_dq0(3,3)*d_ig(3);
                    dz_ib_by_dq1 = dR_by_dq1(3,1)*d_ig(1) + dR_by_dq1(3,2)*d_ig(2) + dR_by_dq1(3,3)*d_ig(3);
                    dz_ib_by_dq2 = dR_by_dq2(3,1)*d_ig(1) + dR_by_dq2(3,2)*d_ig(2) + dR_by_dq2(3,3)*d_ig(3);
                    dz_ib_by_dq3 = dR_by_dq3(3,1)*d_ig(1) + dR_by_dq3(3,2)*d_ig(2) + dR_by_dq3(3,3)*d_ig(3);
                    
                    
                    
                    Hi_21 = temp1*(dy_ib_dx*d_ib(1) - dx_ib_dx*d_ib(2)) ;
                    Hi_22 = temp1*(dy_ib_dy*d_ib(1) - dx_ib_dy*d_ib(2)) ;
                    Hi_23 = temp1*(dy_ib_dz*d_ib(1) - dx_ib_dz*d_ib(2)) ;
                    Hi_24 = temp1*(d_ib(1)*dy_ib_by_dq0 -d_ib(2)*dx_ib_by_dq0);
                    Hi_25 = temp1*(d_ib(1)*dy_ib_by_dq1 -d_ib(2)*dx_ib_by_dq1);
                    Hi_26 = temp1*(d_ib(1)*dy_ib_by_dq2 -d_ib(2)*dx_ib_by_dq2);
                    Hi_27 = temp1*(d_ib(1)*dy_ib_by_dq3 -d_ib(2)*dx_ib_by_dq3);
                    
                    
                    
                    Hi_31 = temp2 *(dz_ib_dx*d_ib(1) - dx_ib_dx*d_ib(3));
                    Hi_32 = temp2 *(dz_ib_dy*d_ib(1) - dx_ib_dy*d_ib(3));
                    Hi_33 = temp2 *(dz_ib_dz*d_ib(1) - dx_ib_dz*d_ib(3));
                    Hi_34 = temp2*(d_ib(1)*dz_ib_by_dq0 -d_ib(3)*dx_ib_by_dq0);
                    Hi_35 = temp2*(d_ib(1)*dz_ib_by_dq1 -d_ib(3)*dx_ib_by_dq1);
                    Hi_36 = temp2*(d_ib(1)*dz_ib_by_dq2 -d_ib(3)*dx_ib_by_dq2);
                    Hi_37 = temp2*(d_ib(1)*dz_ib_by_dq3 -d_ib(3)*dx_ib_by_dq3);
                    
                    
                    H(3*i-2:3*i,:) = [ Hi_11,Hi_12,Hi_13,Hi_14,Hi_15,Hi_16,Hi_17;
                        Hi_21,Hi_22,Hi_23,Hi_24,Hi_25,Hi_26,Hi_27;
                        Hi_31,Hi_32,Hi_33,Hi_34,Hi_35,Hi_36,Hi_37];
                end
                
            end
        end
        
        
        function M = dh_dv_func(x,v) %#ok<INUSD>
            error('not implemented yet')
            % Jacobian of observation wrt observation noise.
            M = eye(Landmarks_3D_EulerAngles.obsDim);
        end
        function V = generate_observation_noise(x)
            error('not implemented yet')
            L = Landmarks_3D_EulerAngles.landmarks;
            eta = Landmarks_3D_EulerAngles.eta; %#ok<PROP>
            sigma_b = Landmarks_3D_EulerAngles.sigma_b;%#ok<PROP>
            obsDim = Landmarks_3D_EulerAngles.obsDim;%#ok<PROP>
            N_L = size(L,2);
            
            d = L - repmat(x(1:3),1,N_L);
            ranges = sqrt(d(1,:).^2+d(2,:).^2+d(3,:).^2)';
            
            R_std(1:3:obsDim-2) = eta(1)*ranges+sigma_b(1);%#ok<PROP>
            R_std(2:3:obsDim-1) = eta(2)*ranges+sigma_b(2);%#ok<PROP>
            R_std(3:3:obsDim)   = eta(3)*ranges+sigma_b(3);%#ok<PROP>
            R = diag(R_std.^2);
            
            indep_part_of_obs_noise=randn(obsDim,1); %#ok<PROP>
            V = indep_part_of_obs_noise.*diag(R.^(1/2));
        end
        function R = noise_covariance(x)
            error('not implemented yet')
            od = Landmarks_3D_EulerAngles.obsDim;
            L = Landmarks_3D_EulerAngles.landmarks;
            eta = Landmarks_3D_EulerAngles.eta; %#ok<PROP>
            sigma_b = Landmarks_3D_EulerAngles.sigma_b;%#ok<PROP>
            N_L = size(L,2);
            d = L - repmat(x(1:3),1,N_L);
            ranges = sqrt(d(1,:).^2+d(2,:).^2+d(3,:).^2)';
            R_std(1:3:od-2) = eta(1)*ranges+sigma_b(1);%#ok<PROP>
            R_std(2:3:od-1) = eta(2)*ranges+sigma_b(2);%#ok<PROP>
            R_std(3:3:od)   = eta(3)*ranges+sigma_b(3);%#ok<PROP>
            R=diag(R_std.^2);
        end
        function innov = compute_innovation(Xprd,Zg)
            error('not implemented yet')
            V = zeros(Landmarks_3D_EulerAngles.obsNoiseDim,1);
            Zprd = Landmarks_3D_EulerAngles.h_func(Xprd,V);
            innov = Zg - Zprd;
            singleObsDim = 3;
%             for i=1:size(innov,1)/singleObsDim
%                 innov(singleObsDim*i-2) = Zg(singleObsDim*i-2) - Zprd(singleObsDim*i-2) ; 
%                 innov(singleObsDim*i-1) = delta_theta_turn(Zprd(singleObsDim*i-1), Zg(singleObsDim*i-1), 'ccw');
%                 innov(singleObsDim*i) = delta_theta_turn(Zprd(singleObsDim*i), Zg(singleObsDim*i), 'ccw');
%             end
%             for i=1:size(innov,1)/singleObsDim
%                  
%                 if innov(singleObsDim*i - 1) > pi
%                     innov(singleObsDim*i - 1) = innov(3*i - 1) - 2*pi;
%                 end
%                 if innov(singleObsDim*i - 1) < -pi
%                     innov(singleObsDim*i - 1) = innov(3*i - 1) + 2*pi;
%                 end
%                 if innov(singleObsDim*i) > pi
%                     innov(singleObsDim*i) = innov(3*i) - 2*pi;
%                 end
%                 if innov(singleObsDim*i) < -pi
%                     innov(singleObsDim*i) = innov(3*i) + 2*pi;
%                 end
%             end
            
            wrong_innovs = find(innov>pi | innov<-pi);
            for jjj=1:length(wrong_innovs)
                i=wrong_innovs(jjj);
                if mod(i,2)==0 && innov(i)>pi
                    innov(i)=innov(i)-2*pi;
                elseif mod(i,2)==0 && innov(i)<-pi
                    innov(i)=innov(i)+2*pi;
                end
                if mod(i,3)==0 && innov(i)>pi
                    innov(i)=innov(i)-2*pi;
                elseif mod(i,3)==0 && innov(i)<-pi
                    innov(i)=innov(i)+2*pi;
                end
            end
            for i=1:size(innov,1)/singleObsDim
                
                if innov(singleObsDim*i - 1) > deg2rad(2)
                    innov(singleObsDim*i - 1) = deg2rad(2);
                    disp('large val in innovation');
                end
                if innov(singleObsDim*i - 1) < -deg2rad(2)
                    innov(singleObsDim*i - 1) = -deg2rad(2);
                    disp('large val in innovation');
                end
                if innov(singleObsDim*i) > deg2rad(2)
                    innov(singleObsDim*i) = deg2rad(2);
                    disp('large val in innovation');
                end
                if innov(singleObsDim*i) < -deg2rad(2)
                    innov(singleObsDim*i) = -deg2rad(2);
                    disp('large val in innovation');
                end
 
            end
            
        end
        function old_prop = set_figure() % This function sets the figure (size and other properties) to values that are needed for landmark selection or drawing.
            error('not implemented yet')
            figure(gcf); 
            old_prop{1}=get(gca,'NextPlot');hold on; % save the old "NextPlot" property and set it to "hold on" % Note that this procedure cannot be moved into the "set_figure" function.
            old_prop{2}=get(gca,'XGrid'); % save the old "XGrid" property.
            old_prop{3}=get(gca,'YGrid'); % save the old "YGrid" property.
            grid on; % set the XGrid and YGrid to "on".
            if ~isempty(user_data_class.par.sim.figure_position)
                set(gcf,'Position',user_data_class.par.sim.figure_position)
            end
            axis(user_data_class.par.sim.env_limits);
            set(gca,'DataAspectRatio',[1 1 1]); % makes the scaling of different axes the same. So, a circle is shown as a circle not ellipse.
        end
        function reset_figure(old_prop) % This function resets the figure properties (size and other properties), to what they were before setting them in this class.
            error('not implemented yet')
            set(gca,'NextPlot',old_prop{1}); % reset the "NextPlot" property to what it was.
            set(gca,'XGrid',old_prop{2}); % reset  the "XGrid" property to what it was.
            set(gca,'YGrid',old_prop{3}); % reset  the "YGrid" property to what it was.
        end
    end
    
    methods
        function obj = draw(obj) % note that the "draw" function in this class is "static". Thus, if you call it, you have to assign its output to the "plot_handle" by yourself.
            error('not implemented yet')
            old_prop = Landmarks_3D_EulerAngles.set_figure();
            obj.plot_handle = plot(obj.landmarks(1,:),obj.landmarks(2,:),'kp','markerfacecolor','k','markersize',12);
            Landmarks_3D_EulerAngles.reset_figure(old_prop);
        end
        function obj = delete_plot(obj)
            error('not implemented yet')
            delete(obj.plot_handle)
            obj.plot_handle = [];
        end
    end
end