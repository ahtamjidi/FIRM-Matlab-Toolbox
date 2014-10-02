classdef Hbelief_G % Gaussian H-belief
    properties
        system;
        Xg_mean;
        Xest_mean_mean;
        Pest;   % estimation covariance
        P_of_joint; % covariance of joint distribution of Xg and Xest_mean
        plot_handle;
    end
    
    methods
        function obj = Hbelief_G(Xg_mean, Xest_MeanOfMean, Pest, P_of_joint, system_inp)
            if nargin>0
                obj.system = system_inp;
                obj.Xg_mean = Xg_mean;
                obj.Xest_mean_mean = Xest_MeanOfMean;
                obj.Pest = Pest;
                if ~all(size(P_of_joint)==[2*system_inp.ss.dim,2*system_inp.ss.dim])
                    error('The dimension of joint distribution covariance is not correct.')
                else
                    obj.P_of_joint = P_of_joint;
                end
            end
        end
        function PHb = HbeliefG_to_HbeliefP(obj , num_samples)
            BigX_mean_val = [obj.Xg_mean.val;obj.Xest_mean_mean.val];
            particles = mvnrnd(BigX_mean_val,obj.P_of_joint,num_samples)';
            Hstate_particles(1,num_samples) = Hstate; % preallocating object array
            stDim = obj.system.ss.dim;
            state_class_name = class(obj.system.ss);
            belief_class_name = class(obj.system.belief);
            for q = 2 : num_samples  % q=1 is the noiseless particle, which is defined later below.
                 Hstate_particles(q).Xg = feval(state_class_name , particles(1:stDim,q));
                 Xest_mean = feval(state_class_name , particles(stDim+1:2*stDim,q));
                 Hstate_particles(q).b = feval(belief_class_name, Xest_mean, obj.Pest);
            end
            Hstate_particles(1).Xg = feval(state_class_name, obj.Xg_mean.val); % First particle is the Maximum likelihood particle, thus it should have zero noise.
            % note that in the above line and below line we could omit the
            % "state" constructor. But, the reason we did not so is that we
            % do NOT want the graphic handle of Xg_mean and Xest_mean_mean
            % are copied into the particles.
            Xest_mean_mean_copy = feval(state_class_name, obj.Xest_mean_mean.val);
            Hstate_particles(1).b = feval(belief_class_name, Xest_mean_mean_copy, obj.Pest);
            PHb = Hbelief_p(Hstate_particles);
            PHb.num_p = num_samples;
        end
        function obj = draw(obj)
            spec = {'RobotShape','triangle','RobotSize',0.5,'triaColor','g'};
            tmp=get(gca,'NextPlot'); hold on
            obj.plot_handle = [];
            obj.Xg_mean = obj.Xg_mean.draw(spec{:});
            stDim = obj.system.ss.dim;
            Xg_ellipse_spec = '-g';
            if any(any(obj.P_of_joint(1:2,1:2))) % if the whole covariance matrix is zero, we do not plot the ellipse (point in this case)
                ellipse_handle_g = plotUncertainEllip2D(obj.P_of_joint(1:2,1:2),obj.Xg_mean.val(1:2),Xg_ellipse_spec);
                obj.plot_handle = [obj.plot_handle,ellipse_handle_g];
            end
            Xest_mean_ellipse_spec = '-r';
            if any(any(obj.P_of_joint(stDim+1:stDim+2,stDim+1:stDim+2))) % if the whole covariance matrix is zero, we do not plot the ellipse (point in this case)
                ellipse_handle_Xest_mean_cov = plotUncertainEllip2D(obj.P_of_joint(stDim+1:stDim+2,stDim+1:stDim+2),obj.Xest_mean_mean.val(1:2),Xest_mean_ellipse_spec);
                obj.plot_handle = [obj.plot_handle,ellipse_handle_Xest_mean_cov];
            end
            est_cov_ellipse_spec = '-k';
            if any(any(obj.Pest(1:2,1:2)))
                ellipse_handle_est_cov = plotUncertainEllip2D(obj.Pest(1:2,1:2),obj.Xg_mean.val(1:2),est_cov_ellipse_spec);
                obj.plot_handle = [obj.plot_handle,ellipse_handle_est_cov];
            end
            set(gca,'NextPlot',tmp);
        end
        function obj = delete_plot(obj)
            obj.Xg_mean = obj.Xg_mean.delete_plot();
            obj.Xest_mean_mean = obj.Xest_mean_mean.delete_plot();
            try % Avoid errors if the graphic object has already been deleted
                delete(obj.plot_handle);
                obj.plot_handle = [];
            end
        end
    end
   
end