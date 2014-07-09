classdef Dec_Planning_Problem
    %PLANNING_PROBLEM is a base class, from which one can instantiate a planning problem with a user inputed environment (obstacles and information sources)
    
    properties
        sim;
        PRM;
        FIRM_graph;
        par;
        team;
    end
    
    methods
        function obj = Dec_Planning_Problem(sim, team)
            % in constructor we retrive the paraemters of the planning
            % problem entered by the user.
            obj.par = user_data_class.par.planning_problem_param;
            obj.sim = sim;
            obj.PRM = feval(obj.par.PRMString, team.ss, team.mm);
            obj.team = team;
        end
        function obj = solve(obj)
            [loading_folder_path, ~, ~] = fileparts(user_data_class.par.LoadFileName); % This line returns the path of the folder from which we want to load the parameters.
            Constructed_FIRM_file = [loading_folder_path,filesep,'Constructed_FIRM.mat'];
            [saving_folder_path, ~, ~] = fileparts(user_data_class.par.SaveFileName); % This line returns the path of the folder into which we want to save the parameters.
            % --------------------------------------- Offline construction code
            if obj.par.Offline_construction_phase == 1  % Offline construction code
                
                if strcmpi(obj.par.solver,'Periodic LQG-based FIRM')
                    obj.FIRM_graph = PLQG_based_FIRM_graph_class(obj.PRM); % the input PRM is an object of PNPRM class
                else 
                    obj.FIRM_graph = FIRM_graph_class(obj.PRM); % the input PRM is an object of PNPRM class
                end                
                obj.FIRM_graph = obj.FIRM_graph.construct_all_stabilizers_and_FIRM_nodes(obj.team); % Here, we construct the set of stabilizers used in FIRM and then we construct the reachable nodes under those stabilizers.
                obj.FIRM_graph = obj.FIRM_graph.draw_all_nodes(); drawnow; % Draw the FIRM nodes
                obj.FIRM_graph = obj.FIRM_graph.construct_all_FIRM_edges(); % Construct all the FIRM edges and associated transition costs and probabilities.
                save([saving_folder_path, filesep,'Constructed_FIRM.mat'] , 'obj')  % Actually we are saving an object of "planning_problem" class, NOT only FIRM_graph. So, teh name of file, i.e., "Constructed_FIRM" can be a little misleading.
                
                % --------------------------------------- Online execution code
            elseif obj.par.Online_phase == 1  % Online execution code
                %                     load Data\FIRM17June
                %                     load Data\FIRM24June_3particles
                %                     load Data\FIRM_6July2011_OneParticle
                %                     load Data\FIRM_7July2011_OneParticle
                load(Constructed_FIRM_file); % Actually we are loading an object of "planning_problem" class, NOT only FIRM_graph. So, teh name of file, i.e., "Constructed_FIRM" can be a little misleading.
                % AMIR: I believe we no longer need this since we no longer
                % have separate folder for each run. Therefore I am
                % commenting this
%                 if exist(Constructed_FIRM_file,'file')
%                     copyfile(Constructed_FIRM_file,saving_folder_path)
%                 end
                obj.FIRM_graph = obj.FIRM_graph.draw_all_nodes(); drawnow
                
%                 myaa_Ali('FIRM_nodes_figure') % for producing the FIRM nodes figure for a paper
                
                %% Good Experiment
                % 1 -> 6
                % 6 -> 9
                % 9  -> 21
                %%
                start_node_ind = input('Please input the start node index:  ');
                goal_node_ind = input('Please input the target node index:  ');
                
                continue_sim = 1;
                
                while continue_sim
                    
                    text_height = 0.5;
%                     text(obj.FIRM_graph.PRM.nodes(start_node_ind).val(1)-5,obj.FIRM_graph.PRM.nodes(start_node_ind).val(2),obj.FIRM_graph.PRM.nodes(start_node_ind).val(3)+text_height,'start','color','r','fontsize',14); % we write "start" next to the start node
%                     text(obj.FIRM_graph.PRM.nodes(goal_node_ind).val(1)+5,obj.FIRM_graph.PRM.nodes(goal_node_ind).val(2),obj.FIRM_graph.PRM.nodes(goal_node_ind).val(3)+text_height,'goal','color','r','fontsize',14); % we write "goal" next to the goal node
                    
                    obj.FIRM_graph = obj.FIRM_graph.DP_compute_cost_to_go_values(goal_node_ind);
                    %                 obj.FIRM_graph.feedback_pi(1)=2;
                    %                 obj.FIRM_graph.feedback_pi(5)=12;
                    %                 obj.FIRM_graph.feedback_pi(8)=17;
                    %                 obj.FIRM_graph.feedback_pi(1)=4;
                    %
                    ensemble_size = 1;  % The execution phase only works for a single robot. If you need multiple realization, you have to re-run it multiple times.
                    tmp_pHb = obj.FIRM_graph.Nodes(start_node_ind).sample(ensemble_size); % the "sample" function returns a particle-Hb, with a single particle (since "ensemble_size" is 1).
                    initial_belief = tmp_pHb.Hparticles(1).b; % initialization % we retrive the single Hstate (or Hparticle) from the "tmp_pHb"
                    
                    obj.sim = obj.sim.setRobot(initial_belief.est_mean.val);
                    
                    initial_belief = obj.FIRM_graph.Nodes(start_node_ind).center_b;
                    
                    obj.FIRM_graph = obj.FIRM_graph.Execute(initial_belief,start_node_ind,goal_node_ind,obj.sim);
                    continue_sim = input('Enter 1 to continute, 0 to stop :  ');
                    if continue_sim
                        start_node_ind = goal_node_ind;
                        goal_node_ind = input('Please input a new target node index:  ');
                    end
                    
                end
                
            end
            if user_data_class.par.sim.video == 1;  close(vidObj);  end
        end
    end
    
    
    
end
