%Prismatic Robot manipulator Prismatic link class
%
% A subclass of the Link class: holds all information related to a robot 
% link such as kinematics parameters, rigid-body inertial parameters, motor
% and transmission parameters.
%
% Notes::
% - This is reference class object
% - Link class objects can be used in vectors and arrays
%
% References::
% - Robotics, Vision & Control, Chap 7
%   P. Corke, Springer 2011.
%
% See also Link, Revolute, SerialLink.

% Copyright (C) 1993-2011, by Peter I. Corke
%
% This file is part of The Robotics Toolbox for Matlab (RTB).
% 
% RTB is free software: you can redistribute it and/or modify
% it under the terms of the GNU Lesser General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% RTB is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU Lesser General Public License for more details.
% 
% You should have received a copy of the GNU Leser General Public License
% along with RTB.  If not, see <http://www.gnu.org/licenses/>.
classdef Prismatic < Link
    methods
        function L = Prismatic(varargin)
            L = L@Link(varargin{:});
            
            if nargin == 0
                L.d = [];
            end
            if isempty(L.theta)
                L.theta = 0;
            end
            if ~isempty(L.d)
                error('d cannot be specified for a prismatic link');
            end
            L.sigma = 1;
        end
    end
end