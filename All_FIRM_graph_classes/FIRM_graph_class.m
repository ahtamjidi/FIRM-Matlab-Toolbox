classdef FIRM_graph_class < FIRM_graph_interface
    %FIRM_Stationary_LQG_based_class is the FIRM class based on stationary LQG controllers.
    
    properties (Access = private)
        time_of_edge_construction; % time it takes the algorithm to construct and edge along with its collision probabilities and costs.
    end
    
    methods
        function obj = FIRM_graph_class(system_inp,PRM_inp)
            obj = obj@FIRM_graph_interface(system_inp,PRM_inp);
            obj.num_stabilizers = obj.PRM.num_stabilizers;
            obj.num_edges = size(PRM_inp.edges_list,1); % number of local controllers
            
            obj.Stabilizers = feval([user_data_class.par.planning_problem_param.stabilizerString '.empty']);
            obj.Stabilizers(obj.num_stabilizers,1) = feval(user_data_class.par.planning_problem_param.stabilizerString); % Preallocate object array
            
            obj.Nodes = FIRM_node_class.empty;
            obj.Nodes(obj.num_nodes,1) = FIRM_node_class; % Preallocate object array
            obj.Edges = FIRM_edge_class.empty;
            obj.Edges(obj.num_edges,1) = FIRM_edge_class; % Preallocate object array
        end
        function obj = construct_all_stabilizers_and_FIRM_nodes(obj)
            % This function constructs stabilizers used in the FIRM framework and constructs reachable nodes under this stabilizers and assigns values to the "stabilizers" and "nodes" properties of the class.
            obj.num_nodes = obj.PRM.num_nodes;
            tic
            % we design the stabilizers (belief point stabilizers) in the following loop.
            for jn = 1:obj.num_stabilizers % jn is the stabilizer number
                disp(['Constructing belief node stabilizer ',num2str(jn),' out of total ',num2str(obj.num_stabilizers),' stabilizers'])
                PRM_node = obj.PRM.nodes(jn);
%                 obj.Stabilizers(jn) = stabilizer_class(PRM_node);  % constructing i-th stabilizer
                obj.Stabilizers(jn) = feval(user_data_class.par.planning_problem_param.stabilizerString, PRM_node, obj.system);
                obj.Stabilizers(jn).stabilizer_number = jn;  % We need this for display purposes in the "stabilizer_class". However, we do not provide it as a constructor input, since it is not a real property of the class.
            end
            n = 0; % n represents the absolute number of nodes (Not associated with a single stabilizer, but among all nodes)
            for jn = 1:obj.num_stabilizers % jn is the stabilizer number (or belief node center number in this class)
                obj.Stabilizers(jn) = obj.Stabilizers(jn).construct_reachable_FIRM_nodes();
                reachable_FIRM_nodes = obj.Stabilizers(jn).reachable_FIRM_nodes;
                num_of_reachable_nodes = length(reachable_FIRM_nodes);
                disp(['Constructing FIRM nodes ',num2str(n+1:n+num_of_reachable_nodes),' out of total ',num2str(obj.num_nodes),' nodes'])
                for alpha = 1:num_of_reachable_nodes  % alpha is the counter for nodes on a single stabilizer
                    n = n+1; % n represents the absolute number of nodes (Not associated with a single stabilizer, but among all nodes)
                    obj.Nodes(n) = reachable_FIRM_nodes(alpha);
                    obj.Nodes(n).number = n;
                end
            end
            disp(['Time elapsed for creating all ',num2str(obj.num_nodes),' nodes is ',num2str(toc),' seconds'])
        end
        function obj = construct_all_FIRM_edges(obj)
            % This function constructs FIRM edges and assigns values to the "edges" property of the class.
            n = 0; % total edge number counter
            %             for i_s = 1:obj.num_stabilizers
                %                 for alpha = 1:???
                %
                %                 end
                %             end
            disp('This function has to be updated totally')
            
            
            for i = 1:obj.num_edges
                tic
                disp(['Constructing edge ',num2str(i),' ...'])
                start_node_ind = obj.PRM.edges_list(i,1);
                end_node_ind = obj.PRM.edges_list(i,2);
                % The following funtion generates the open-loop edge trajectories.
                PRM_edge_traj = obj.PRM.edges(i); % the end_ind has to be orbit. But since right now we only have a single node on each orbit, they are the same.
                % To test correcness
                %                 for iii=1:length(PRM_edge_traj.x)
                %                     xp=state(PRM_edge_traj.x(:,iii));
                %                     xp.draw('RobotShape','triangle','triacolor','g','color','g');
                %                 end
                
                starting_FIRM_node = obj.Nodes(start_node_ind);
                possible_end_node_indices = end_node_ind;
                end_edge_stabilizer = obj.Stabilizers(end_node_ind);
                edge_ind = i;
                
                obj.Edges(i) = FIRM_edge_class(obj.system, starting_FIRM_node , possible_end_node_indices , end_edge_stabilizer , edge_ind , PRM_edge_traj );
                obj.Edges(i) = obj.Edges(i).construct();
                obj.Nodes(start_node_ind).outgoing_edges = [obj.Nodes(start_node_ind).outgoing_edges , edge_ind];
                obj.time_of_edge_construction(i) = toc;
            end
        end
        function obj = Execute(obj,initial_belief, start_node_ind,goal_node_ind,sim)
            current_belief = initial_belief;
            current_node_ind = start_node_ind;
            while current_node_ind ~= goal_node_ind
                next_edge_ind = obj.feedback_pi(current_node_ind); % compute the next edge (next optimal local controller) on the graph using high level feedback "pi" on the graph.
                [next_belief, lost, YesNo_unsuccessful, landed_node_ind, sim] = obj.Edges(next_edge_ind).execute(current_belief,sim);
                if YesNo_unsuccessful
                    disp('Ali: Execution is failed, as the robot either collided with an obstacle or ran out of time.')
                    break
                end
                if user_data_class.par.replanning == 1 % see if the replanning is allowed
                    if lost
                        next_belief.est_cov = next_belief.est_cov*2; % we increase the initial uncertainty as we assume that the estimation covariance is not realistic
                        obj.replan(next_belief, goal_node_ind); % Note that this function should not output "obj". The reason is explained inside the function.
                        return; % after replanning, we do not continue the loop anymore, becuase the whole plan is changed.
                    end
                end
                current_belief = next_belief;
                current_node_ind = landed_node_ind;
            end
        end
    end
    
    methods (Access = private)
        function obj = add_a_node_and_its_sequel(obj,b)
            % FIRM node
            new_node_ind = obj.num_nodes + 1;
            temporary_FIRM_node = FIRM_node_class(b); % Important: Note that the belief "b" constructs a temporary FIRM node and it is used to produce the new edges and their costs from the belief we lost at. However we will UPDATE this node by its real "stationary_belief", so that it can be used later as the end node of some other edges.
            %             % inserting singleton GHb to the node
            %             singleton_GHb = Hbelief_G(b.est_mean,b.est_mean,b.est_cov,blkdiag(b.est_cov,zeros(state.dim)));
            %             obj.Nodes(new_node_ind).stationary_GHb = singleton_GHb;
            
            % set the new number of nodes by one
            obj.num_nodes = obj.PRM.num_nodes;
            % draw the temporary FIRM node
            temporary_FIRM_node = temporary_FIRM_node.draw();drawnow;
            % new edges
            old_num_of_edges = obj.num_edges;
            obj.num_edges = size(obj.PRM.edges_list,1);
            for i = old_num_of_edges+1 : obj.num_edges
                disp(['Constructing edge ',num2str(i),' ...'])
                start_node_ind = obj.PRM.edges_list(i,1);
                end_node_ind = obj.PRM.edges_list(i,2);
                % The following funtion generates the open-loop edge trajectories.
                PRM_edge_traj = obj.PRM.edges(i); % the end_ind has to be orbit. But since right now we only have a single node on each orbit, they are the same.
                
                possible_end_node_indices = end_node_ind;
                end_edge_stabilizer = obj.Stabilizers(end_node_ind);
                edge_ind = i;
                obj.Edges(i) = FIRM_edge_class(temporary_FIRM_node , possible_end_node_indices , end_edge_stabilizer , edge_ind , PRM_edge_traj );
                if ~user_data_class.par.goBack_to_nearest_node % if, in replanning, we go to the nearest node, we do not need to compute the uncertainty porpagation along the newly added edges.
                    obj.Edges(i) = obj.Edges(i).construct();
                end
                
                temporary_FIRM_node.outgoing_edges = [temporary_FIRM_node.outgoing_edges , edge_ind];
            end
            
            temporary_FIRM_node = temporary_FIRM_node.delete_plot();drawnow;
            
            % In the following line we compute the real stationary FIRM
            % node
            % corresponding to the new node. Note that this has to be done
            % after computing edges.
            % Note that the reason we have to update this "stationary_GHb"
            % from "singleton" value to this value, is that this newly
            % added node can be the "end node" of some other edges which
            % may be added later.
            disp('Following is wrong!! because, if you want to use the added node again in the planning, the costs has to be computed based on the stationary GHb, not the singleton GHb.')
            
            disp(['Constructing new belief point Stabilizer ',num2str(new_node_ind)])
            PRM_node = obj.PRM.nodes(new_node_ind);
            obj.Stabilizers(new_node_ind) = Point_stabilizer_SLQG_class(PRM_node);  % constructing i-th stabilizer
            obj.Stabilizers(new_node_ind).stabilizer_number = new_node_ind;  % We need this for display purposes in the "Point_stabilizer_SLQG_class". However, we do not provide it as a constructor input, since it is not a real property of the class.
            disp(['Constructing real FIRM node ',num2str(new_node_ind)])
            obj.num_stabilizers = obj.num_stabilizers+1;
            obj.Stabilizers(new_node_ind) = obj.Stabilizers(new_node_ind).construct_reachable_FIRM_nodes();
            obj.Nodes(new_node_ind) = obj.Stabilizers(new_node_ind).reachable_FIRM_nodes;  % In this case there will be a single "reachable node". So, we directly copy it into the "obj.Nodes(jn)"
             obj.Nodes(new_node_ind) =  obj.Nodes(new_node_ind).draw();drawnow;
            obj.Nodes(new_node_ind).outgoing_edges = temporary_FIRM_node.outgoing_edges;
%             obj.Nodes(new_node_ind).stationary_GHb = obj.Nodes(new_node_ind).stationary_GHb.draw();
        end
        function replan(obj, next_belief, goal_node_ind)
            % Note that we must NOT output the "obj" in
            % this function, because we do not want the newly added node
            % gets added to the main graph. We want the other robot (the
            % next runs), use the same original graph. Thus, we want to treat the new nodes as the
            % temporary nodes.
            new_node_ind = obj.PRM.num_nodes + 1; % this is the number of first newly added node (which coincides the existing estimation right at this point).
            obj.PRM = obj.PRM.add_node(next_belief.est_mean); drawnow; % add a node to PRM
            obj = obj.add_a_node_and_its_sequel(next_belief); drawnow;% add a node to FIRM
            if user_data_class.par.goBack_to_nearest_node
                nearest_node_ind = obj.PRM.compute_nearest_node_ind(new_node_ind);
                obj.feedback_pi(new_node_ind) = nearest_node_ind;
            else
                % in FIRM, we need to update the "feedback pi" too. Note that we are doing this in a naive way by updating whole values. The computationally less expensive way is only to compute the newly added node. However, the benefit of the current method is if we want to add the node to the graph (i.e. the new nodes which comes later can get connected to it.) this is correct to update the whole values.
                obj = obj.DP_compute_cost_to_go_values(goal_node_ind);
            end
            obj.Execute(next_belief,new_node_ind,goal_node_ind);
        end
    end
    
end
