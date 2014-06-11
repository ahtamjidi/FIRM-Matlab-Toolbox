classdef Six_DOF_robot_belief < Gaussian_belief_interface
    % This class encapsulates the Gaussian belief concept.

    methods
        function obj = Six_DOF_robot_belief(varargin)
            obj = obj@Gaussian_belief_interface(varargin{:});
        end
        function obj = draw(obj, varargin)
            % The full list of properties for this function is:
            % 'RobotShape', 'RobotSize', 'TriaColor', 'color', 'HeadShape',
            % 'HeadSize', 'EllipseSpec'.
                
            New_varargin={};
            
            for i = 1 : 2 : length(varargin)
                switch lower(varargin{i})
                    case lower('EllipseSpec')
                        ellipse_spec = varargin{i+1};
                    case lower('EllipseWidth')
                        ellipse_width = varargin{i+1};
                    otherwise  % So, if the "varargin" is anything else, it is related to the plotting of "mean". So, we collect such inputs in "New_varargin" and pass them to the "obj.est_mean.draw".
                        New_varargin{end+1} = varargin{i}; %#ok<AGROW>
                        New_varargin{end+1} = varargin{i+1}; %#ok<AGROW> % Note that in previous line the "end" itself is increased by 1. Thus, this line is correct.
                end
            end
            
            obj.est_mean = obj.est_mean.draw(New_varargin{:});
           
            tmp=get(gca,'NextPlot'); hold on
            m = obj.est_mean.val(1:3);
            C = obj.est_cov(1:3,1:3);
            sdwidth = 2;
%             obj.ellipse_handle = plot_gaussian_ellipsoid(m, C, sdwidth);
            set(gca,'NextPlot',tmp);
        end
        function obj = draw_CovOnNominal(obj, nominal_state, varargin)
            % This function draws the belief. However, the estimation
            % covarinace is centered at the nominal state, provided by the
            % function caller.
             m = nominal_state.val(1:3);
             C = obj.est_cov(1:3,1:3);
             sdwidth = 2;
%              obj.ellipse_handle = plot_gaussian_ellipsoid(m, C, sdwidth);
        end
        function obj = apply_differentiable_constraints(obj)
            obj.est_mean = obj.est_mean.apply_differentiable_constraints();
            constraint_Jacobian = obj.est_mean.get_differentiable_constraints_jacobian();
            obj.est_cov = constraint_Jacobian*obj.est_cov*constraint_Jacobian';
        end
    end
end