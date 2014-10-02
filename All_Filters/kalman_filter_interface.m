classdef kalman_filter_interface < filter_interface
    % This class encapsulates different variants of Kalman Filter.
    methods (Abstract)
        obj = estimate(obj, varargin)
    end
    methods
        function b_prd = predict(obj, b, U, lnr_sys, system)
            % lnr_sys is the linear or linearized system, Kalman filter is
            % designed for.
            
            A = lnr_sys.A;
            %B = lnr_sys.B; % not needed in this function
            G = lnr_sys.G;
            Q = lnr_sys.Q;
            
            % Pprd=(A-B*L)*Pest_old*(A-B*L)'+Q;  % wroooooong one
            
            Xest_old = b.est_mean.val;
            Pest_old = b.est_cov;
            
            zerow = system.mm.zeroNoise;
            Xprd = system.mm.f_discrete(Xest_old,U,zerow);
            
            % I removed following display, because it comes up there too
            % many times!
            %disp('AliFW: for LKF, it seems more correct to use linear prediction step.')
            
            
            %Xprd = A*Xest_old+B*U; % This line is veryyyyyyyyyy
            %wroooooooooooooooooooooooooong. Because, this equation only
            %holds for state error NOT the state itself.
            Pprd = A*Pest_old*A'+G*Q*G';
            
            Xprd_state = feval(class(system.ss), Xprd);
            
            b_prd = belief(Xprd_state, Pprd);
        end
        function b = update(obj, b_prd, Zg, lnr_sys, system)
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
            b=bout;
        end
    end
end