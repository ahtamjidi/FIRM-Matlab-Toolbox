classdef LKF < kalman_filter_interface

    methods(Static = true)

        function b_next = estimate(b,U,Zg,lnr_sys_for_prd,lnr_sys_for_update, system)
            if nargin < 5
                error('Ali: The linearized systems has to be provided for LKF.')
            end
            b_prd = LKF.predict(b,U,lnr_sys_for_prd, system);
            b_next = LKF.update(b_prd,Zg,lnr_sys_for_update, system);
        end
        function b_prd = predict(b,U,lnr_sys, system)
            
            % lnr_sys is the linear or linearized system, Kalman filter is
            
            % designed for.
            

            A = lnr_sys.A;
            
            %B = lnr_sys.B; % not needed in this function
            
            G = lnr_sys.G;
            
            Q = lnr_sys.Q;

            % Pprd=(A-B*L)*Pest_old*(A-B*L)'+Q;  % wroooooong one
            
            Xest_old = b.est_mean.val;
            
            Pest_old = b.est_cov;

            zerow = zeros(system.mm.wDim,1);
            
            Xprd = system.mm.f_discrete(Xest_old,U,zerow);
            
           
            % I removed following display, because it comes up there too
            
            % much times!
            
            %disp('AliFW: for LKF, it seems more correct to use linear prediction step.')
            
            
            %Xprd = A*Xest_old+B*U; % This line is veryyyyyyyyyy
            
            %wroooooooooooooooooooooooooong. Because, this equation only
            
            %holds for state error NOT the state itself.
            
            Pprd = A*Pest_old*A'+G*Q*G';

            Xprd_state = feval(class(system.ss), Xprd);
            
            b_prd = feval(class(system.belief), Xprd_state, Pprd);
            
        end
        
        function b = update(b_prd,Zg,lnr_sys, system)
            
            % lnr_sys is the linear or linearized system, Kalman filter is
            
            % designed for.
            
            H = lnr_sys.H;
            
            R = lnr_sys.R;
            
            Pprd = b_prd.est_cov;
            
            % I think in following line changing "inv" to "pinv" fixes possible
            
            % numerical issues
            
            KG = (Pprd*H')/(H*Pprd*H'+R); %KG is the "Kalman Gain"
            
            Xprd = b_prd.est_mean.val;
            
            innov = system.om.compute_innovation(Xprd,Zg);
            
            Xest_next = Xprd+KG*innov;
            
            Pest_next = Pprd-KG*H*Pprd;
            
            Xnext_state = feval(class(system.ss), Xest_next);
            
            b = feval(class(system.belief),Xnext_state,Pest_next);
            
            bout = b.apply_differentiable_constraints(); % e.g., quaternion norm has to be one
            
            b = bout;
            
        end
        
        function KGain_seq_for_LKF = Kalman_Gain_seq_for_LKF(lnr_sys_seq,initial_Pest,kf) %#ok<INUSD,STOUT>
            error('So far, there is no need for this function to be used.')
            % memory preallocation
            KG = cell(1,kf+1); %#ok<UNRCH>
            % Solving Forward Riccati to compute Time-varying gains
            Pest = initial_Pest;
            
            for k = 1 : kf % we must solve this Riccati BACKWARDS
                % Jacobians at time k
                A = lnr_sys_seq(k).A;
                G = lnr_sys_seq(k).G;
                Q = lnr_sys_seq(k).Q;
                % Jacobians at time k+1
                H = lnr_sys_seq(k+1).H;
                R = lnr_sys_seq(k+1).R;
                
                Pprd = A*Pest*A'+G*Q*G';
                KG{k+1} = (Pprd*H')/(H*Pprd*H'+R); %KG is the "Kalman Gain" which is associated with the time k+1.
                Pest = Pprd-KG{k+1}*H*Pprd;
            end
            KGain_seq_for_LKF = KG;
            
        end
    end
end