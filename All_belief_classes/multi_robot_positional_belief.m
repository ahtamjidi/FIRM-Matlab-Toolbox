classdef multi_robot_positional_belief < Gaussian_belief_interface
    % This class encapsulates the Gaussian belief concept.

    properties (Constant = true)
       stateClassString = 'multi_robot_positional_state'; 
    end
    
    properties 
        num_robots
    end
    
    methods
        function obj = multi_robot_positional_belief(varargin)
           obj = obj@Gaussian_belief_interface(varargin{:});
           if nargin == 1
                if (strcmpi(class(varargin{1}),'Gaussian_belief_interface'))
                    %arg1 is of type 'belief'
                    obj.num_robots = varargin{1}.num_robots;
                else
                    %arg1 is of type 'state'
                    obj.num_robots = varargin{1}.num_robots;
                end
           elseif nargin == 2
               %arg1 is of type 'state'
               obj.num_robots = varargin{1}.num_robots;
           end
        end
        function obj = draw(obj, varargin)
            % The full list of properties for this function is:
            % 'RobotShape', 'RobotSize', 'TriaColor', 'color', 'HeadShape',
            % 'HeadSize', 'EllipseSpec'.
            
            ellipse_spec = {'-r','-g','-b'};  % Default value for "EllipseSpec" property.
            ellipse_width = 2;
            ellipse_magnify = 1;
            New_varargin={};
            
            for i = 1 : 2 : length(varargin)
                switch lower(varargin{i})
                    case lower('EllipseSpec')
                        % ellipse_spec = varargin{i+1};
                    case lower('EllipseWidth')
                        ellipse_width = varargin{i+1};
                    case lower('EllipseMagnify')
                        ellipse_magnify = varargin{i+1};
                    otherwise  % So, if the "varargin" is anything else, it is related to the plotting of "mean". So, we collect such inputs in "New_varargin" and pass them to the "obj.est_mean.draw".
                        New_varargin{end+1} = varargin{i}; %#ok<AGROW>
                        New_varargin{end+1} = varargin{i+1}; %#ok<AGROW> % Note that in previous line the "end" itself is increased by 1. Thus, this line is correct.
                end
            end
            obj.est_mean = obj.est_mean.draw(New_varargin{:});
           if ~isempty(ellipse_spec)
               tmp=get(gca,'NextPlot'); hold on
               obj.ellipse_handle = [];
               
               
               for j = 1:obj.num_robots
                   tmp_h = plotUncertainEllip2D(obj.est_cov(2*j-1:2*j  , 2*j-1:2*j),obj.est_mean.val(2*j-1:2*j), ellipse_spec{j}, ellipse_width,ellipse_magnify);
                   obj.ellipse_handle = [obj.ellipse_handle , tmp_h];
               end
               set(gca,'NextPlot',tmp);
            end
        end
        function obj = draw_CovOnNominal(obj, nominal_state, varargin)
            % This function draws the belief. However, the estimation
            % covarinace is centered at the nominal state, provided by the
            % function caller.
            
            ellipse_spec = {'-r','-g','-b'};  % Default value for "EllipseSpec" property.
            ellipse_width = 2;
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
           if ~isempty(ellipse_spec)
                tmp=get(gca,'NextPlot'); hold on
                obj.ellipse_handle = [];
               for j = 1:obj.num_robots
                   tmp_h = plotUncertainEllip2D(obj.est_cov(2*j-1:2*j  , 2*j-1:2*j),nominal_state.val(2*j-1:2*j),ellipse_spec{j}, ellipse_width);
                   obj.ellipse_handle = [obj.ellipse_handle , tmp_h];
               end
                set(gca,'NextPlot',tmp);
            end
        end
    end
end