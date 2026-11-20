%% 
clear()
clc()

%% 
script_dir = fileparts(matlab.desktop.editor.getActiveFilename);
ressources_dir = fullfile(script_dir, 'Ressources');
code_dir = fullfile(ressources_dir, 'Code');
save_path = fullfile(script_dir,'Saved_files');
code_dir_Julien = fullfile(script_dir, 'Code');

addpath(ressources_dir);
addpath(code_dir);
addpath(fullfile(code_dir, 'bem-sf'));
addpath(fullfile(ressources_dir, 'Body_models'));
addpath(fullfile(code_dir, 'external'));
addpath(fullfile(code_dir, 'iso2mesh'));
addpath(fullfile(code_dir, 'pns_toolbox'));
addpath(fullfile(code_dir, 'BMM-FEM'));
addpath(fullfile(code_dir, 'BMM-FEM/Engine'));
pns_toolbox = fullfile(code_dir, 'pns_toolbox');
addpath(genpath(fullfile(code_dir, 'external/YALMIP')));
addpath(fullfile(ressources_dir, 'Mosek/11.2/toolbox/r2019b'));
setenv('MOSEKLM_LICENSE_FILE', fullfile(ressources_dir, 'Mosek/mosek.lic'));
fmm3d_lib_dir = fullfile(code_dir, 'FMM3D-master', 'lib');
setenv('LD_LIBRARY_PATH', [fmm3d_lib_dir, ':', getenv('LD_LIBRARY_PATH')]);
addpath(fullfile(code_dir, 'FMM3D-master', 'matlab'));

%% Data preparation
    
% define which setups to run in parallel
% workspaces      = dir('D:\scratch\davids\Matlab\BEM-SF v2\ISMRM_2022');
% workspaces      = arrayfun( @(id) [ workspaces(id).folder, '\', workspaces(id).name ], (3 : numel(workspaces)).', 'UniformOutput', false  );

workspaces      = { ...
                  fullfile(save_path,'Impulse_Zshift/Right_branch/XYsym/Impulse_Xaxis_5p7%_0p06/'), ...
                  };
                
coil_axes       = {'x'};      	% usually we design all coils

save_suffix     = '_v1'; 

coil_sym_axes               = 'xy';
opt_models = {'male','female'};   % {'male'} | {'female'} | {'male','female'}

use_coil_design_surface     = [ ];
use_nodal_basis_functions   = [ ]; % empty = all

% SWEEP PHASES
% X: Improve field linearity            
% X: Active shielding                   ??? --> 5e-7
% X: PNS optimization                   ??? --> 0.4
% X: Torque-Force Balancing             6.1 / 0.12  --> 0.5 / 0.10
% X: Wire spacing and bending radius

% PRISMA
%==============
% X-AXIS
% Geff      = 0.085 mT/m/A 
% Shield    = 5e-6 T/A
% Lin       = 14.01% 
% Torque    = 1.8 Nm/A
% Force     = 1.4 N/A

% Y-AXIS
% Geff      = 0.085 mT/m/A 
% Shield    = 5e-6 T/A
% Lin       = 13.42% 
% Torque    = 3.6 Nm/A
% Force     = 3.0 N/A

% IMPULSE
%==============
% X-AXIS
% Geff      = 0.160 mT/m/A 
% Shield    = 1.25e-6 T/A
% Lin       = 6.0% 
% Torque    = 0.17 Nm/A
% Force     = 0.30 N/A
% Wires     = 86   1/m

% PRISMA
%------------
% C_max_sweep   	= 0.14;       	% [%]       Bz error constraints
% G_max_sweep     = nan;          % [%]       G error efficiency
% A_max_sweep     = 2.50e-06;     	% [mT]      active shielding, field amplitude at cryostat
% G_eff_sweep     = 0.09e-3;   	% [mT/m/A]  gradient field efficiency
% D_max_sweep     = 125; %1 / 0.008; 	% [1/m]     wires per meter   
% T_max_sweep     = 1.8;  	% [Nm/A]    torque per unit current, ALL layer combined
% TL_max_sweep    = nan;        	% [Nm/A]    torque per unit current, INDIVIDUAL layers
% F_max_sweep     = 1.4;  	% [N/A]     force per unit current, ALL layer combined
% FL_max_sweep    = nan;        	% [N/A]     force per unit current, INDIVIDUAL layers
% W_max_sweep     = 3000;       	% [N/A]     bending radius

% IMPULSE
%------------
C_max_sweep   	         = [0.057];%,  0.10, 0.15, 0.20];     	% [%]       Bz error constraints
G_max_sweep              = nan;         % [%]       G error efficiency
A_max_sweep              = 1.25e-3;     % [mT]      active shielding, field amplitude at cryostat
G_eff_sweep              = 0.16e-3;   	% [T/m/A]  gradient field efficiency
D_max_sweep              = 86;          % 1 / 0.008; 	% [1/m]     wires per meter   
T_max_sweep              = 0.17;  	    % [Nm/A]    torque per unit current, ALL layer combined
TL_max_sweep             = nan;        	% [Nm/A]    torque per unit current, INDIVIDUAL layers
F_max_sweep              = 0.30;  	    % [N/A]     force per unit current, ALL layer combined
FL_max_sweep             = nan;        	% [N/A]     force per unit current, INDIVIDUAL layers
W_max_sweep              = 4000;       	% [N/A]     bending radius
alpha_shift_sweep        = [0.06 0.07 0.08 0.09 0.1];      % [N/A]     Percentage of variation for +/-20mm
Pshift_branch            = 'plus';      % 'both' | 'plus' (convex) | 'minus' (not convex) -- branch to optimize
alpha_tilt_sweep         = [0.02]; % [-] tolerance for +/-angle tilt (front/back)
Ptilt_branch             = 'both';      % 'both' | 'plus' | 'minus'
enable_Pshift_constraint = true;
enable_Ptilt_constraint  = false;
enable_Pequality         = true;   % PNS max = Target PNS
eq_all_groups            = true;   % false : only the most restrictiv model

% PNS constraints (drop factor) for each P-matrix, single value means that
% value is used for all iterations (constant). Zero means that the initial
% PNS value is kept constant throughout the iterates
P_rel_vec       = 0.0 : 0.005 : 0.6; %0.0 : 0.05 : 0.6;
P_constr_all   = { ...
    %   Relative PNSO Red.      Cnstr. ID           Body region IDX
        P_rel_vec,              'M_head_HFS',       [1,2]; ...
%         P_rel_vec,              'M_cardiac_HFS',  	[1,2]; ...
%         P_rel_vec,              'M_pelvic_FFS',  	[1,2]; ...
%         P_rel_vec,              'M_abdominal_FFS', 	[1,2]; ...
%         P_rel_vec,              'M_pelvic_HFS',  	[1,2]; ...
%         P_rel_vec,              'M_abdominal_HFS', 	[1,2]; ...
        P_rel_vec,             	'F_head_HFS',       [1,2]; ...
%         P_rel_vec,             	'F_cardiac_HFS',  	[1,2]; ...
%         P_rel_vec,              'F_pelvic_FFS',  	[1,2]; ...
%         P_rel_vec,              'F_abdominal_FFS', 	[1,2]; ...
%         P_rel_vec,              'F_pelvic_HFS',  	[1,2]; ...
%         P_rel_vec,              'F_abdominal_HFS', 	[1,2]; ...
    };



pfx_map  = struct('male','M_', 'female','F_');
pfx_list = cell(1, numel(opt_models));
for imod = 1 : numel(opt_models)
    if ~isfield(pfx_map, lower(opt_models{imod}))
        error('opt_models must only contain ''male'' and/or ''female''')
    end
    pfx_list{imod} = pfx_map.(lower(opt_models{imod}));
    if ~any(startsWith(P_constr_all(:,2), pfx_list{imod}))
        error('No PNS constraint for the model "%s"', opt_models{imod})
    end
end
P_constr = P_constr_all( startsWith(P_constr_all(:,2), pfx_list), : );
if numel(opt_models) == 1, model_tag = [lower(opt_models{1}), 'only']; else, model_tag = 'both'; end

P_type  = 2;
% 1: constrain each P-matrix individually
% 2: constrain worst-case per model

max_age_mins    = 120; % [min]

% all other design constraints, NaN values will be overwritten later
opts.symmetry   = coil_sym_axes;
opts.grad_efficiency = nan;
opts.C_max    	= nan;    	% relative error in ROL
opts.A_max      = nan; 	% absolute field tolerated outside 
opts.P_max    	= nan;
opts.D_max    	= nan;     % wires per meter
opts.T_max    	= nan;     % Nm/A % let's aim for 0.3 kN/m at 1000A
opts.TL_max   	= nan;     % Torque constraint per layer
opts.F_max    	= nan;     % N/A % let's aim for 1.0 kN at 1000A
opts.FL_max   	= nan;     % Force constraint per layer
opts.W_max    	= nan;

% which constraints to use
opts.use_C_constraint      = 1;   % leave this on
opts.use_G_constraint      = 0;   % or this one
opts.use_A_constraint      = 1;
opts.use_D_constraint      = 1;
opts.use_T_constraint      = 1;
opts.use_TL_constraint     = 0;
opts.use_F_constraint      = 1;
opts.use_FL_constraint     = 0;
opts.use_P_constraint      = 0; % keep at zero, will be overwritten
opts.use_W_constraint      = 1; 
opts.use_Pshift_constraint = 0;
opts.use_Ptilt_constraint  = 0;

% Set some options for YALMIP/MOSEK solver
mosek_opts = sdpsettings('verbose',2); %2
mosek_opts = sdpsettings(mosek_opts,'debug',1); %1
mosek_opts = sdpsettings(mosek_opts,'showprogress',1); %1

mosek_opts.solver = 'mosek';
mosek_opts.mosek.MSK_DPAR_INTPNT_CO_TOL_DFEAS      = 1e-10;    % 1e-8 
mosek_opts.mosek.MSK_DPAR_INTPNT_CO_TOL_REL_GAP    = 1e-10;    % 1e-8 
mosek_opts.mosek.MSK_DPAR_INTPNT_TOL_PATH          = 1e-8;     % 1e-8 INC
mosek_opts.mosek.MSK_DPAR_INTPNT_TOL_STEP_SIZE     = 1e-8;     % 1e-6
mosek_opts.mosek.MSK_DPAR_INTPNT_CO_TOL_REL_GAP    = 1e-8;     % 1e-8
mosek_opts.mosek.MSK_DPAR_BASIS_TOL_X              = 1e-4;     % 1e-6
mosek_opts.mosek.MSK_DPAR_BASIS_TOL_S              = 1e-4;     % 1e-6 INC

if ~enable_Ptilt_constraint, alpha_tilt_sweep = alpha_tilt_sweep(1); end
% we define the loop over L-curves, so that we can parallelize efficiently
[ C_max_all, A_max_all, G_max_all, G_eff_all, D_max_all, T_max_all, TL_max_all, F_max_all, FL_max_all, W_max_all, alpha_shift_all, alpha_tilt_all, coil_ax_all, workspace_all ]	= ndgrid( ...
                                                                                                                                              1 : numel( C_max_sweep ), ...
                                                                                                                                              1 : numel( A_max_sweep ), ...
                                                                                                                                              1 : numel( G_max_sweep ), ...
                                                                                                                                              1 : numel( G_eff_sweep ), ...
                                                                                                                                              1 : numel( D_max_sweep ), ...
                                                                                                                                              1 : numel( T_max_sweep ), ...
                                                                                                                                              1 : size( TL_max_sweep,1 ), ...
                                                                                                                                              1 : numel( F_max_sweep ), ...
                                                                                                                                              1 : size( FL_max_sweep,1 ), ...
                                                                                                                                              1 : numel( W_max_sweep ), ...
                                                                                                                                              1 : numel( alpha_shift_sweep ),...
                                                                                                                                              1 : numel( alpha_tilt_sweep ),...
                                                                                                                                              1 : numel( coil_axes ), ...
                                                                                                                                              1 : numel( workspaces ) );

nloop         	= numel( workspace_all );
n_pns_iter    	= numel( P_rel_vec );
if ~ismember(Pshift_branch, {'both','plus','minus'})
    error('Pshift_branch doit valoir ''both'', ''plus'' ou ''minus''!')
end
% flags to check when system matrices need to be updated
if ~exist( 'sys_w_index', 'var' )
    sys_w_index     = 0;
end
Sx_w_index      = 0;
Sy_w_index      = 0;
Sz_w_index      = 0;

% define the save folder name
if ~isempty( coil_sym_axes )
    save_suffix = sprintf( '%ssym_%s', upper( coil_sym_axes ), save_suffix );
end
save_suffix = strrep( save_suffix, '__', '_' );
if ~isempty( save_suffix )
   if ~strcmp( save_suffix(1),'_' )
      save_suffix = [ '_', save_suffix ]; 
   end
end

% some aux data needed to compute phantom E-fields
Female_phantom      = load(fullfile(pns_toolbox,'Female_phantom_v1_mesh.mat'));
Male_phantom     	= load(fullfile(pns_toolbox,'Male_phantom_v1_mesh.mat'));

n_P_constraints     = size(P_constr,1);

for par = 1 : nloop

    % collect all parameters
    C_max_cur       = C_max_sweep( C_max_all( par ) );
    A_max_cur       = A_max_sweep( A_max_all( par ) );
    G_max_cur       = G_max_sweep( G_max_all( par ) );
    G_eff_cur       = G_eff_sweep( G_eff_all( par ) );
    D_max_cur       = D_max_sweep( D_max_all( par ) );
    T_max_cur       = T_max_sweep( T_max_all( par ) );
    TL_max_cur      = TL_max_sweep( TL_max_all( par ),: );
    F_max_cur       = F_max_sweep( F_max_all( par ) );
    FL_max_cur      = FL_max_sweep( FL_max_all( par ),: );
    W_max_cur       = W_max_sweep( W_max_all( par ) );
    alpha_shift     = alpha_shift_sweep( alpha_shift_all( par ) );
    alpha_tilt      = alpha_tilt_sweep( alpha_tilt_all(par) );
    grad_type       = coil_axes{ coil_ax_all(par) };
    w               = workspace_all(par);
    workspace_cur   = workspaces{ w };
    
    % set current constraints
    opts.C_max           = C_max_cur;   
    opts.G_max           = G_max_cur;  
    opts.A_max           = A_max_cur; 
    opts.grad_efficiency = G_eff_cur;
    opts.D_max           = D_max_cur;    
    opts.T_max           = T_max_cur;   
    opts.TL_max          = TL_max_cur;  
    opts.F_max           = F_max_cur;   
    opts.FL_max          = FL_max_cur;  
    opts.W_max           = W_max_cur;
    
    % load all data
  	matrices_name = sprintf('%s/matrices.mat',workspaces{w});
    if ~exist( matrices_name, 'file' )
        warning('"%s" not found!',matrices_name)
        continue
    end
    
    % iterate over all coil axes to be designed
    %-------------------------------------------

    alpha_tag = [];
    if enable_Pshift_constraint
        alpha_tag = [alpha_tag, strrep(sprintf('alpha%.3f', alpha_shift), '.', 'p')];
    end
    if enable_Ptilt_constraint
        alpha_tag = [alpha_tag, '_', strrep(sprintf('tilt%.3f', alpha_tilt), '.', 'p')];
    end
    alpha_tag = [alpha_tag, '_', model_tag];
    save_folder     = sprintf('%s/%saxis%s/%s', strrep(workspace_cur,'scratch',''), upper(grad_type), save_suffix, alpha_tag);

    % create folder
    if exist( save_folder, 'dir' ) == 0
        mkdir( save_folder )
    end
        
    % iterate over all linearity constraints to be used
    %---------------------------------------------------

    % iterate over all relative PNS constraint values
    %-------------------------------------------------
    for p = 1 : max(1,n_pns_iter)

        % we check if the first dataset exists (either empty or with results)
        % this indicates that another process is handling this case and
        % we do not need to process it
        save_name = sprintf('%s/%saxis',save_folder,upper(grad_type));
        if opts.use_C_constraint, save_name = sprintf('%s_Crol_%i',save_name,round(100*C_max_cur)); end
        if opts.use_A_constraint, save_name = sprintf('%s_Cshd_%.2e',save_name,A_max_cur); end
        save_name = sprintf('%s_Geff_%i',save_name,1e+6*G_eff_cur);
        if opts.use_D_constraint, save_name = sprintf('%s_Dmax_%i',save_name,round(D_max_cur)); end
        if opts.use_T_constraint, save_name = sprintf('%s_Tmax_%.2e',save_name,T_max_cur); end
        if opts.use_F_constraint, save_name = sprintf('%s_Fmax_%.2e',save_name,F_max_cur); end
        if opts.use_W_constraint, save_name = sprintf('%s_Wmax_%i',save_name,round(W_max_cur)); end
        if n_P_constraints>0, save_name = sprintf('%s_PNS_%.3f',save_name,P_rel_vec(p)); end
        save_name = [ strrep( save_name, '.', 'p' ), '.mat' ];
        
%         save_name = sprintf('%s/C_%03i_PNS_%03i.mat',save_folder,round(1000*C_rol_cur),round(1000*P_rel_vec(p)));  
        
      	if exist(save_name,'file')
            % load the previous dataset; we need the PNS performance to
            % correctly set PNS constraints in the following steps
            prevdat  = load( save_name );
            
            % get the "age" of the file (Linux-compatible)
            d               = dir( save_name );
            file_age_mins   = minutes( datetime('now') - datetime(d.datenum,'ConvertFrom','datenum') );
            
            if isfield( prevdat, 'output' ) && ~isfield( prevdat, 'sf_solution' )
                break
            elseif ~isfield( prevdat, 'sf_solution' )
                if file_age_mins <= max_age_mins
                    break 
                else
                    sf_solution = [];
                    save( save_name, 'sf_solution' )
                end
            elseif isempty( prevdat.sf_solution )
                if file_age_mins <= max_age_mins
                    continue 
                else
                    sf_solution = [];
                    save( save_name, 'sf_solution' )
                end
            else
                if p == 1
                    pm = prevdat.P_matrices;
                    ci = cellfun( @(nm) find(strcmpi(pm(:,1), nm), 1), P_constr(:,2) );   % P-matrices contraintes, dans l'ordre de P_constr
                    PNSO_cur_max    = prevdat.sf_solution.metrics.PNS_oracle( ci, : );
                    PNSO0_shift_ref = max( PNSO_cur_max(:) );
                end
                clear prevdat
                continue
            end
        else
            % create placeholder dataset
            sf_solution = [];
            save( save_name, 'sf_solution' )
        end

        % some command output
        fprintf('\n')
        fprintf(' Running: "%s"\n', save_name)
        fprintf(repmat('-',1,13+numel(save_name)))
        fprintf('\n\n')
        
        if sys_w_index ~= w
           sys_w_index = w;
           load( matrices_name ) 
           nlayer = numel( sf_design.coil_node_layerid );
           
           warning('Setting TL and FL to zero!')
           TL   = 0;
           FL   = 0;
        
        end
        
        if isfield( sf_design, 'P_matrix_constraint' )
            sf_design.P_matrix_name = sf_design.P_matrix_constraint;
            sf_design = rmfield( sf_design, 'P_matrix_constraint' );
        end
        if exist('P_constraints', 'var')
           P_matrices = P_constraints;
           clear P_constraints
        end
        n_P_matrices     = size( P_matrices,1 );
        constr_pm_idx = zeros(1, size(P_constr,1));
        for ic = 1 : size(P_constr,1)
            ii = find( strcmpi(P_matrices(:,1), P_constr{ic,2}), 1 );
            if isempty(ii), error('P-matrix "%s" missing from P_matrices', P_constr{ic,2}), end
            constr_pm_idx(ic) = ii;
        end
        sel_np = constr_pm_idx;
        
        %% --------------------------------------------

        % this is important!
        yalmip('clear')
        
        % number of PNS constrained iterations (number of L-curve points)
        n_P_constraints   = size(P_constr,1);
        n_P_bodyregions   = numel( unique( P_bodyregion_idx ) );
%         if n_P_constraints > 0
%             n_P_bodyregions   = unique(cellfun( @(c) numel(c), P_constr(:,3) ));
%             if numel(n_P_bodyregions) > 2, error('"P_constr" not defined correctly!'), end
%         else
%             n_P_bodyregions = 0;
%         end
        
        % set and enable the relevant PNS constraint
        if n_P_constraints > 0
            if p == 1
                opts.use_P_constraint   = 0;
                PNSO_cur_max         	= inf( n_P_constraints, n_P_bodyregions );
                opts.P_max              = [ arrayfun( @(np) {max(PNSO_cur_max(np,P_constr{np,3})) * (1 - P_constr{np,1}(p))}, (1 : n_P_constraints).' ), P_constr(:,2:3) ];
                opts.use_Pshift_constraint = false;
                opts.use_Ptilt_constraint  = false;
                PNSO0_shift_ref            = inf;
            else
                opts.use_P_constraint   = 1;
                opts.use_Pshift_constraint = enable_Pshift_constraint;
                opts.use_Ptilt_constraint  = enable_Ptilt_constraint;
                switch P_type
                    case 1
                        % apply PNS constraint scaling to each P-matrix
                        % individually, i.e., each scan application with
                        % exhibit PNS reduction factors
                        opts.P_max              = [ arrayfun( @(np) {NaN}, (1 : n_P_constraints).' ), P_constr(:,2:3) ];
                    case 2
                        % get worst-case PNS per body model and apply
                        % global PNS constraint to all P-matrices
                        % corresonding to the same body mode
                        opts.P_max              = [ arrayfun( @(np) {max(PNSO_cur_max(np,P_constr{np,3})) * (1 - P_constr{np,1}(p))}, (1 : n_P_constraints).' ), P_constr(:,2:3) ];
                        for ppi = 1 : n_P_constraints
                            % get model index
                            P_model     = P_matrices{ cellfun( @(Pname) strcmpi( P_constr{ppi,2}, Pname ), P_matrices(:,1) ), 4 };
                            P_all_model = cellfun( @(str1) any( cellfun( @(str2) strcmpi( str1, str2 ), P_matrices( cell2mat(P_matrices(:,4)) == P_model ,1) ) ), P_constr(:,2) );
                            P_all_idx   = ( 1 : n_P_constraints ).';
                            P_cur_max   = max( arrayfun( @(np) max(PNSO_cur_max(np,P_constr{np,3})), P_all_idx( P_all_model ) ) );
                            opts.P_max{ppi,1} = P_cur_max * (1 - P_constr{ppi,1}(p));
                        end
                end
            end
        end

        % symmetry appropriate system matrices
        if Sx_w_index ~= w && strcmpi( grad_type, 'x' )
            %  X   A X I S 
            %--------------
            Sx_w_index       = w;
            
            S_gx             = get_nodal_constraint_matrix( sf_design, 'x', coil_sym_axes, use_coil_design_surface, use_nodal_basis_functions, sf_design.encoding_component );
            S_gx             = reduce_rectangular_matrix( S_gx.', sf_design.boundary ).';
            S_gx(:,all( S_gx == 0, 1 )) = [];

            % get symmetry-enforced system matrices
            Cs_gx  = C * S_gx;
            GXs_gx  = GX * S_gx;
            GYs_gx  = GY * S_gx;
            GZs_gx  = GZ * S_gx;
            Gs_gx 	= [ GXs_gx;       	GYs_gx;        	GZs_gx ];
            As_gx  = A * S_gx;
            Ts_gx  = T * S_gx;
            TLs_gx = TL * S_gx;
            Fs_gx  = F * S_gx;
            FLs_gx = FL * S_gx;
            Ps_gx  = P * S_gx;
            Ps_gx_shift_plus = [];  Ps_gx_shift_minus = [];
            Ps_gx_angle_plus_theta = [];  Ps_gx_angle_minus_theta = [];
            if enable_Pshift_constraint && ismember(Pshift_branch,{'both','plus'}),  Ps_gx_shift_plus  = P_shift_plus  * S_gx; end
            if enable_Pshift_constraint && ismember(Pshift_branch,{'both','minus'}), Ps_gx_shift_minus = P_shift_minus * S_gx; end
            if enable_Ptilt_constraint  && ismember(Ptilt_branch, {'both','plus'}),  Ps_gx_angle_plus_theta  = P_angle_plus_theta  * S_gx; end
            if enable_Ptilt_constraint  && ismember(Ptilt_branch, {'both','minus'}), Ps_gx_angle_minus_theta = P_angle_minus_theta * S_gx; end
            Ds_gx  = D * S_gx;
            Ws_gx  = W * S_gx;
            Rs_gx  = S_gx.' * R * S_gx;
            Ls_gx  = S_gx.' * L * S_gx;
            
            try chol(Ls_gx);
                %disp('Matrix is symmetric positive definite.')
            catch ME
                error('Matrix is not symmetric positive definite')
            end

            clear P_shift_plus P_shift_minus P_angle_plus_theta P_angle_minus_theta
            % remove redundant rows (i.e., redundant constraints)
            Ds_gx = remove_redundant_constraints( Ds_gx );
        end

        if Sy_w_index ~= w && strcmpi( grad_type, 'y' )
            %  Y   A X I S 
            %--------------
            Sy_w_index       = w;
            S_gy             = get_nodal_constraint_matrix( sf_design, 'y', coil_sym_axes, use_coil_design_surface, use_nodal_basis_functions, sf_design.encoding_component );
            S_gy             = reduce_rectangular_matrix( S_gy.', sf_design.boundary ).';
            S_gy(:,all( S_gy == 0, 1 )) = [];

            % get symmetry-enforced system matrices
            Cs_gy = C * S_gy;
            GXs_gy  = GX * S_gy;
            GYs_gy  = GY * S_gy;
            GZs_gy  = GZ * S_gy;
            Gs_gy 	= [ GXs_gy;       	GYs_gy;        	GZs_gy ];
            As_gy  = A * S_gy;
            Ts_gy  = T * S_gy;
            TLs_gy = TL * S_gy;
            Fs_gy  = F * S_gy;
            FLs_gy = FL * S_gy;
            Ps_gy = P * S_gy;
            Ds_gy = D * S_gy;
            Ws_gy = W * S_gy;
            Rs_gy = S_gy.' * R * S_gy;
            Ls_gy = S_gy.' * L * S_gy;
            
            try chol(Ls_gy);
                %disp('Matrix is symmetric positive definite.')
            catch ME
                error('Matrix is not symmetric positive definite')
            end

            % remove redundant rows (i.e., redundant constraints)
            Ds_gy = remove_redundant_constraints( Ds_gy );
        end

        if Sz_w_index ~= w && strcmpi( grad_type, 'z' )
            %  Z   A X I S 
            %--------------
            Sz_w_index       = w;
            S_gz             = get_nodal_constraint_matrix( sf_design, 'z', coil_sym_axes, use_coil_design_surface, use_nodal_basis_functions, sf_design.encoding_component );
            S_gz             = reduce_rectangular_matrix( S_gz.', sf_design.boundary ).';
            S_gz(:,all( S_gz == 0, 1 )) = [];

            % get symmetry-enforced system matrices
            Cs_gz = C * S_gz;
            Ts_gz  = T * S_gz;
            GXs_gz  = GX * S_gz;
            GYs_gz  = GY * S_gz;
            GZs_gz  = GZ * S_gz;
            Gs_gz 	= [ GXs_gz;       	GYs_gz;        	GZs_gz ];
            As_gz  = A * S_gz;
            TLs_gz = TL * S_gz;
            Fs_gz  = F * S_gz;
            FLs_gz = FL * S_gz;
            Ps_gz = P * S_gz;
            Ds_gz = D * S_gz;
            Ws_gz = W * S_gz;
            Rs_gz = S_gz.' * R * S_gz;
            Ls_gz = S_gz.' * L * S_gz;
            
            try chol(Ls_gz);
                %disp('Matrix is symmetric positive definite.')
            catch ME
                error('Matrix is not symmetric positive definite')
            end
            
        end

        % Set target fields
        %------------------

        % BZ TARGET POINTS:
        % we enforce target Bz values on the outer surface of the ROL
        opts.C_coord   	= sf_design.rolext_node; 
        switch lower( grad_type )
            case 'x', opts.C_target 	= opts.C_coord(:,1) * opts.grad_efficiency; 
            case 'y', opts.C_target 	= opts.C_coord(:,2) * opts.grad_efficiency; 
            case 'z', opts.C_target 	= opts.C_coord(:,3) * opts.grad_efficiency; 
        end
        opts.C_lb       = opts.C_target - opts.C_max * max(abs(opts.C_target));
        opts.C_ub       = opts.C_target + opts.C_max * max(abs(opts.C_target));

        % G TARGET POINTS:
        % we enforce a target gradient in the interior of the ROL
        opts.G_coord   	= sf_design.rolint_node; 
        switch lower( grad_type )
            case 'x' 
                opts.GX_target 	= ones(size(GX,1),1) * opts.grad_efficiency; 
                opts.GY_target 	= zeros(size(GY,1),1); 
                opts.GZ_target 	= zeros(size(GZ,1),1); 
            case 'y'
                opts.GX_target 	= zeros(size(GX,1),1); 
                opts.GY_target 	= ones(size(GY,1),1) * opts.grad_efficiency; 
                opts.GZ_target 	= zeros(size(GZ,1),1); 
            case 'z'
                opts.GX_target 	= zeros(size(GX,1),1); 
                opts.GY_target 	= zeros(size(GY,1),1); 
                opts.GZ_target 	= ones(size(GZ,1),1) * opts.grad_efficiency; 
        end
        opts.GX_lb  = opts.GX_target - opts.G_max * opts.grad_efficiency;
        opts.GX_ub  = opts.GX_target + opts.G_max * opts.grad_efficiency;
        opts.GY_lb  = opts.GY_target - opts.G_max * opts.grad_efficiency;
        opts.GY_ub  = opts.GY_target + opts.G_max * opts.grad_efficiency;
        opts.GZ_lb  = opts.GZ_target - opts.G_max * opts.grad_efficiency;
        opts.GZ_ub  = opts.GZ_target + opts.G_max * opts.grad_efficiency;

        % combine into single constraint
        G               = [ GX;             GY;             GZ ];
        opts.G_target   = [ opts.GX_target; opts.GY_target; opts.GZ_target ];
        opts.G_lb       = [ opts.GX_lb;     opts.GY_lb;     opts.GZ_lb ];
        opts.G_ub       = [ opts.GX_ub;     opts.GY_ub;     opts.GZ_ub ];

        % ACTIVE SHIELDING TARGET POINTS:
        % we enforce a zero field at the shield
        opts.A_coord   	= sf_design.shield_node; 
        opts.A_target   = zeros(size(opts.A_coord,1),1);
        opts.A_lb       = ones(size(opts.A_coord,1),1) * -opts.A_max;
        opts.A_ub       = ones(size(opts.A_coord,1),1) * +opts.A_max;

        % constraint scaling
        opts.L_scale = 1.0;
        opts.A_scale = 1.0;
        opts.C_scale = 1.0;
        opts.G_scale = 1.0;
        opts.D_scale = 1.0;
        opts.T_scale = 1.0;
        opts.F_scale = 1.0;
        opts.P_scale = 1.0;
        opts.W_scale = 1.0;
        
        % prepare the PNS constraint
        if n_P_constraints > 0
            opts.P_lb       = nan( size(P_constr_idx) );
            opts.P_ub       = nan( size(P_constr_idx) );
            opts.P_active   = false( size(P_constr_idx) );
            for pc = 1 : size( opts.P_max,1 )
                if isnumeric( opts.P_max{pc,2} )
                    cur_constr_idx = opts.P_max{pc,2};
                elseif ischar( opts.P_max{pc,2} )
                    cur_constr_idx = find(cellfun( @(str) strcmpi( opts.P_max{pc,2}, str), P_matrices(:,1) ));
                    if isempty(cur_constr_idx)
                        error('No matching PNS constraint for string "%s"!',opts.P_max{pc,2})
                    end
                end
                is_cur_constr   = ismember( P_constr_idx, cur_constr_idx ) & ismember( P_bodyregion_idx, opts.P_max{pc,3} );
                opts.P_lb( is_cur_constr )      = -1 * opts.P_max{pc,1} * opts.grad_efficiency;
                opts.P_ub( is_cur_constr )      = +1 * opts.P_max{pc,1} * opts.grad_efficiency;
                opts.P_active( is_cur_constr )  = 1;
            end
        end


        % S O L V E   W I T H   N O D A L   C O N S T R A I N T S
        %---------------------------------------------------------

        % pick the gradient axis specific system matrices and solve the problem
        switch lower( grad_type )
            case 'x' 

                % solve the reduced symmetric problem
                x = sdpvar(size(Ls_gx,2),1); % define the size of the objective

                L_max       = max(abs(Ls_gx(:)));
                objective   = [ x' * opts.L_scale/L_max * Ls_gx * x ];

                % set the remaining boundaries
                opts.D_lb    = -opts.D_max * ones(size(Ds_gx,1),1);
                opts.D_ub    = +opts.D_max * ones(size(Ds_gx,1),1);
                opts.T_lb    = -opts.T_max * ones(size(Ts_gx,1),1);
                opts.T_ub    = +opts.T_max * ones(size(Ts_gx,1),1);
                opts.F_lb    = -opts.F_max * ones(size(Fs_gx,1),1);
                opts.F_ub    = +opts.F_max * ones(size(Fs_gx,1),1);
                opts.W_lb    = -opts.W_max * ones(size(Ws_gx,1),1);
                opts.W_ub    = +opts.W_max * ones(size(Ws_gx,1),1);

                % set the constraints
                constraints = [];
                if opts.use_C_constraint
                    constraints = [ constraints, opts.C_scale/opts.C_max * opts.C_lb <=  opts.C_scale/opts.C_max * Cs_gx * x  <= opts.C_scale/opts.C_max * opts.C_ub ];
                end
                if opts.use_G_constraint
                    constraints = [ constraints, opts.G_scale/opts.G_max * opts.G_lb <=  opts.G_scale/opts.G_max * Gs_gx * x  <= opts.G_scale/opts.G_max * opts.G_ub ];
                end
                if opts.use_A_constraint
                    constraints = [ constraints, opts.A_scale/opts.A_max * opts.A_lb <=  opts.A_scale/opts.A_max * As_gx * x  <= opts.A_scale/opts.A_max * opts.A_ub ];
                end
                if opts.use_D_constraint
                    constraints  = [ constraints, opts.D_scale/opts.D_max * opts.D_lb <=  opts.D_scale/opts.D_max * Ds_gx * x  <= opts.D_scale/opts.D_max * opts.D_ub ];
                end
                if opts.use_T_constraint
                    constraints  = [ constraints, opts.T_scale/opts.T_max * opts.T_lb <=  opts.T_scale/opts.T_max * Ts_gx * x  <= opts.T_scale/opts.T_max * opts.T_ub ];
                end
                if opts.use_F_constraint
                    constraints  = [ constraints, opts.F_scale/opts.F_max * opts.F_lb <=  opts.F_scale/opts.F_max * Fs_gx * x  <= opts.F_scale/opts.F_max * opts.F_ub ];
                end
                %if opts.use_P_constraint
                %    constraints  = [ constraints, opts.P_scale/max(cell2mat(opts.P_max(:,1))) * opts.P_lb(opts.P_active) <=  opts.P_scale/max(cell2mat(opts.P_max(:,1))) * Ps_gx(opts.P_active,:) * x  <= opts.P_scale/max(cell2mat(opts.P_max(:,1))) * opts.P_ub(opts.P_active) ];
                %end
                %if opts.use_Pshift_constraint
                %    constraints  = [ constraints, opts.Pshift_lb <= Ps_gx_shift * x <= opts.Pshift_ub ];
                %end
                if opts.use_W_constraint
                    constraints  = [ constraints, opts.W_scale/opts.W_max * opts.W_lb <=  opts.W_scale/opts.W_max * Ws_gx * x  <= opts.W_scale/opts.W_max * opts.W_ub ];
                end

            case 'y' 

                % solve the reduced symmetric problem
                x = sdpvar(size(Ls_gy,2),1); % define the size of the objective

                L_max       = max(abs(Ls_gy(:)));
                objective   = [ x' * opts.L_scale/L_max * Ls_gy * x ];

                opts.D_lb    = -opts.D_max * ones(size(Ds_gy,1),1);
                opts.D_ub    = +opts.D_max * ones(size(Ds_gy,1),1);
                opts.T_lb    = -opts.T_max * ones(size(Ts_gy,1),1);
                opts.T_ub    = +opts.T_max * ones(size(Ts_gy,1),1);
                opts.F_lb    = -opts.F_max * ones(size(Fs_gy,1),1);
                opts.F_ub    = +opts.F_max * ones(size(Fs_gy,1),1);
                opts.W_lb    = -opts.W_max * ones(size(Ws_gy,1),1);
                opts.W_ub    = +opts.W_max * ones(size(Ws_gy,1),1);

                % set the constraints
                constraints = [];
                if opts.use_C_constraint
                    constraints = [ constraints, opts.C_scale/opts.C_max * opts.C_lb <=  opts.C_scale/opts.C_max * Cs_gy * x  <= opts.C_scale/opts.C_max * opts.C_ub ];
                end
                if opts.use_G_constraint
                    constraints = [ constraints, opts.G_scale/opts.G_max * opts.G_lb <=  opts.G_scale/opts.G_max * Gs_gy * x  <= opts.G_scale/opts.G_max * opts.G_ub ];
                end
                if opts.use_A_constraint
                    constraints = [ constraints, opts.A_scale/opts.A_max * opts.A_lb <=  opts.A_scale/opts.A_max * As_gy * x  <= opts.A_scale/opts.A_max * opts.A_ub ];
                end
                if opts.use_D_constraint
                    constraints  = [ constraints, opts.D_scale/opts.D_max * opts.D_lb <=  opts.D_scale/opts.D_max * Ds_gy * x  <= opts.D_scale/opts.D_max * opts.D_ub ];
                end
                if opts.use_T_constraint
                    constraints  = [ constraints, opts.T_scale/opts.T_max * opts.T_lb <=  opts.T_scale/opts.T_max * Ts_gy * x  <= opts.T_scale/opts.T_max * opts.T_ub ];
                end
                if opts.use_F_constraint
                    constraints  = [ constraints, opts.F_scale/opts.F_max * opts.F_lb <=  opts.F_scale/opts.F_max * Fs_gy * x  <= opts.F_scale/opts.F_max * opts.F_ub ];
                end
                if opts.use_P_constraint
                    constraints  = [ constraints, opts.P_scale/max(cell2mat(opts.P_max(:,1))) * opts.P_lb(opts.P_active) <=  opts.P_scale/max(cell2mat(opts.P_max(:,1))) * Ps_gy(opts.P_active,:) * x  <= opts.P_scale/max(cell2mat(opts.P_max(:,1))) * opts.P_ub(opts.P_active) ];
                end
                if opts.use_W_constraint
                    constraints  = [ constraints, opts.W_scale/opts.W_max * opts.W_lb <=  opts.W_scale/opts.W_max * Ws_gy * x  <= opts.W_scale/opts.W_max * opts.W_ub ];
                end

            case 'z' 

                % solve the reduced symmetric problem
                x = sdpvar(size(Ls_gz,2),1); % define the size of the objective

                L_max       = max(abs(Ls_gz(:)));
                objective   = [ x' * opts.L_scale/L_max * Ls_gz * x ];

                % set the remaining boundaries
                opts.D_lb    = -opts.D_max * ones(size(Ds_gz,1),1);
                opts.D_ub    = +opts.D_max * ones(size(Ds_gz,1),1);
                opts.T_lb    = -opts.T_max * ones(size(Ts_gz,1),1);
                opts.T_ub    = +opts.T_max * ones(size(Ts_gz,1),1);
                opts.F_lb    = -opts.F_max * ones(size(Fs_gz,1),1);
                opts.F_ub    = +opts.F_max * ones(size(Fs_gz,1),1);
                opts.W_lb    = -opts.W_max * ones(size(Ws_gz,1),1);
                opts.W_ub    = +opts.W_max * ones(size(Ws_gz,1),1);

                % set the constraints
                constraints = [];
                if opts.use_C_constraint
                    constraints = [ constraints, opts.C_scale/opts.C_max * opts.C_lb <=  opts.C_scale/opts.C_max * Cs_gz * x  <= opts.C_scale/opts.C_max * opts.C_ub ];
                end
                if opts.use_G_constraint
                    constraints = [ constraints, opts.G_scale/opts.G_max * opts.G_lb <=  opts.G_scale/opts.G_max * Gs_gz * x  <= opts.G_scale/opts.G_max * opts.G_ub ];
                end
                if opts.use_A_constraint
                    constraints = [ constraints, opts.A_scale/opts.A_max * opts.A_lb <=  opts.A_scale/opts.A_max * As_gz * x  <= opts.A_scale/opts.A_max * opts.A_ub ];
                end
                if opts.use_D_constraint
                    constraints  = [ constraints, opts.D_scale/opts.D_max * opts.D_lb <=  opts.D_scale/opts.D_max * Ds_gz * x  <= opts.D_scale/opts.D_max * opts.D_ub ];
                end
                if opts.use_T_constraint
                    constraints  = [ constraints, opts.T_scale/opts.T_max * opts.T_lb <=  opts.T_scale/opts.T_max * Ts_gz * x  <= opts.T_scale/opts.T_max * opts.T_ub ];
                end
                if opts.use_F_constraint
                    constraints  = [ constraints, opts.F_scale/opts.F_max * opts.F_lb <=  opts.F_scale/opts.F_max * Fs_gz * x  <= opts.F_scale/opts.F_max * opts.F_ub ];
                end
                if opts.use_P_constraint
                    constraints  = [ constraints, opts.P_scale/max(cell2mat(opts.P_max(:,1))) * opts.P_lb(opts.P_active) <=  opts.P_scale/max(cell2mat(opts.P_max(:,1))) * Ps_gz(opts.P_active,:) * x  <= opts.P_scale/max(cell2mat(opts.P_max(:,1))) * opts.P_ub(opts.P_active) ];
                end
                if opts.use_W_constraint
                    constraints  = [ constraints, opts.W_scale/opts.W_max * opts.W_lb <=  opts.W_scale/opts.W_max * Ws_gz * x  <= opts.W_scale/opts.W_max * opts.W_ub ];
                end

        end

        %=======================================================
        %         S O L V E   T H E   P R O B L E M
        %=======================================================
        % When adding P_shift, fiber has not enough memory to run the code
        % We thus find a solution on a set of lines of P_shift and check
        % if this constraint is verified for the whole matrix.
        if ~exist('act_prev','var') || p == 1 && par == 1, act_prev = struct('P',[],'rob',{{}}); end
        n_add = 5000;  tol = 1e-6;  tol_ok = 10*tol;

        famP = [];
        if opts.use_P_constraint
            famP = rob_family('PNS', Ps_gx, P_constr_idx, 0);
            ubP  = opts.P_ub;  ubP(~opts.P_active) = inf;
            famP.ub = ubP;
            if numel(act_prev.P) == numel(ubP), famP.act = act_prev.P; end   % depart a chaud
        end

        fam = [];
        if strcmpi(grad_type,'x') && (opts.use_Pshift_constraint || opts.use_Ptilt_constraint)
            rs = ismember(P_shift_constr_idx, sel_np);
            rt = ismember(P_angle_constr_idx_theta, sel_np);
            if opts.use_Pshift_constraint && ismember(Pshift_branch,{'both','plus'})
                fam = [fam, rob_family('shift +', Ps_gx_shift_plus(rs,:),  P_shift_constr_idx(rs), alpha_shift)]; end
            if opts.use_Pshift_constraint && ismember(Pshift_branch,{'both','minus'})
                fam = [fam, rob_family('shift -', Ps_gx_shift_minus(rs,:), P_shift_constr_idx(rs), alpha_shift)]; end
            if opts.use_Ptilt_constraint && ismember(Ptilt_branch,{'both','plus'})
                fam = [fam, rob_family('tilt +',  Ps_gx_angle_plus_theta(rt,:),  P_angle_constr_idx_theta(rt), alpha_tilt)]; end
            if opts.use_Ptilt_constraint && ismember(Ptilt_branch,{'both','minus'})
                fam = [fam, rob_family('tilt -',  Ps_gx_angle_minus_theta(rt,:), P_angle_constr_idx_theta(rt), alpha_tilt)]; end
            for k = 1:numel(fam)
                if numel(act_prev.rob) >= k && numel(act_prev.rob{k}) == numel(fam(k).act)
                    fam(k).act = act_prev.rob{k};
                end
            end
        end
        nP = numel(famP);
        
        ref_fun = @(xv) rob_ref(Ps_gx*xv, P_constr_idx, opts.P_active, sel_np, n_P_matrices);
        P_ref   = nan(n_P_matrices,1);
        for np = sel_np
            m = P_constr_idx==np & opts.P_active;
            if any(m), P_ref(np) = max(opts.P_ub(m)); end
        end
        if ~isempty(fam)
            if ~enable_Pequality
                warning('Warning : It is not granteed that we will reach the requested PNS reduction factor (p) for all groups. Use enable_Pequality = true to enforce equality on one line per group.')
            end
            for k = 1:numel(fam)
                if any(isnan(P_ref(fam(k).groups)))
                    error('Shift/tilt : P_max indefini for a group.')
                end
                ub_g      = P_ref / (1 - fam(k).alpha);
                fam(k).ub = ub_g(fam(k).grp);
            end
            fprintf('  [shift] P_max (m/T) = %s\n', mat2str(P_ref(sel_np).'/opts.grad_efficiency,4))
        end

        [x_cur, output, Fout] = lazy_solve(constraints, objective, x, famP, mosek_opts, tol, n_add, 50);
        if output.problem == 0, famP = Fout; end

        if enable_Pequality && output.problem == 0 && nP > 0
            v    = abs(famP.M * x_cur);
            fin  = isfinite(famP.ub);
            sat  = zeros(size(v));  sat(fin) = v(fin) ./ famP.ub(fin);    % saturation relative a la borne PROPRE de chaque modele
            gids = unique(famP.grp(fin));
            gmax = arrayfun(@(g) max(sat(famP.grp==g & fin)), gids);
            if eq_all_groups
                sel_g = (1:numel(gids)).';                                 % une ligne d'egalite par modele
            else
                [~, sel_g] = min(gmax);                                    % seulement le groupe le moins sature
            end
            eq_row = zeros(numel(sel_g),1);
            for ig = 1:numel(sel_g)
                rows       = find(famP.grp==gids(sel_g(ig)) & fin);
                [~, j]     = max(sat(rows));                               % ligne de crete de ce groupe
                eq_row(ig) = rows(j);
            end
            famP.eq  = eq_row;
            famP.sgn = sign(famP.M(eq_row,:) * x_cur);
            famP.act(eq_row) = false;
            fprintf('  [egalite PNS] groupes %s, lignes %s, signes %s\n', mat2str(gids(sel_g).'), mat2str(eq_row.'), mat2str(famP.sgn.'))
        end

        if output.problem == 0 && (~isempty(fam) || (nP > 0 && ~isempty(famP.eq)))
            [x_cur, output, Fout] = lazy_solve(constraints, objective, x, [famP, fam], mosek_opts, tol, n_add, 50);
            if output.problem == 0
                famP = Fout(1:nP);  fam = Fout(nP+1:end);
            end
        end
        rel = 0;  fp_converged = true;
        
        % --- Robustness ---
        rob = struct('name',{{}}, 'alpha_eff',{{}}, 'viol',{{}}, 'pshift_converged',true, ...
                     'ptilt_converged',true, 'fp_converged',fp_converged, 'fp_gap',rel);
        if output.problem == 0 && ~isempty(fam)
            nom_true = ref_fun(x_cur);
            rob.name = {fam.name};  rob.alpha_eff = cell(1,numel(fam));  rob.viol = cell(1,numel(fam));
            for k = 1:numel(fam)
                v  = abs(fam(k).M * x_cur);
                sh = arrayfun(@(g) max(v(fam(k).grp == g)), fam(k).groups);
                rob.alpha_eff{k} = 1 - nom_true(fam(k).groups) ./ sh;
                rob.viol{k}      = fam(k).viol;
                fprintf('  %-8s : variation du seuil = %s %% (cible %.1f %%)\n', fam(k).name, ...
                        mat2str(100*rob.alpha_eff{k}(:).',3), 100*fam(k).alpha)
            end
            ok_k = arrayfun(@(f) all(f.viol <= tol_ok), fam);
            isS = startsWith({fam.name},'shift');  isT = startsWith({fam.name},'tilt');
            rob.pshift_converged = ~any(isS) || all(ok_k(isS));
            rob.ptilt_converged  = ~any(isT) || all(ok_k(isT));
            act_prev.P = []; if nP > 0, act_prev.P = famP.act; end
            act_prev.rob = {fam.act};
        elseif output.problem == 0 && nP > 0
            act_prev.P = famP.act;
        end

        if output.problem ~= 0
            save( save_name, 'output' )
            break
        end
        
        sf_solution 	= get_void_sf_solution( sf_design, grad_type );
        
        if nP > 0
            fprintf('  PNS max = %.5f | Target = %.5f (m/T)\n', ...
                max(abs(Ps_gx(opts.P_active,:)*x_cur))/opts.grad_efficiency, ...
                max(cell2mat(opts.P_max(:,1))));
        end

        switch lower( grad_type )
            case 'x'
                sf_solution.sol_reduced = S_gx * double(x);
            case 'y'
                sf_solution.sol_reduced = S_gy * double(x);
            case 'z'
                sf_solution.sol_reduced = S_gz * double(x);
        end

        %sf_solution.pshift_ref = ref_used/opts.grad_efficiency;
        %sf_solution.pshift_fp_gap = rel;
        sf_solution.sol_full    = expand_vector( sf_solution.sol_reduced, sf_design.boundary );
        sf_solution.robust           = rob;
        sf_solution.pshift_converged = rob.pshift_converged;
        sf_solution.ptilt_converged  = rob.ptilt_converged;
        sf_solution.fp_converged     = rob.fp_converged;
        % save some options
        sf_solution.opts        = opts;
        sf_solution.mosek_opts  = mosek_opts;


        %=======================================================
        %            P O S T   P R O C E S S I N G
        %=======================================================

        % extract coil windings from stream function solution
        [ wires_raw ]       = extract_wires( sf_solution );
        sf_solution.wires   = simplify_wires( wires_raw );

        if false
            %myfigure
            %hold on
            %plot_coil( sf_solution.wires )
            %plot_stream_function( sf_solution, sf_solution.sol_full )
            %axis equal
            %setAxes3DPanAndZoomStyle(zoom(gca),gca,'camera')
        end
        
        % figure
        % plot_coil( sf_solution.wires )

        metrics = [];
        metrics.rol_radius = sf_design.rol_radius;
        metrics.linearity  = opts.C_max;
        metrics.sensitivity = opts.grad_efficiency;

        % compute all engineering metric terms from the stream function solution
        %------------------------------------------------------------------------
        metrics.L_sfun   = sf_solution.sol_reduced' * L * sf_solution.sol_reduced;
        metrics.C_sfun   = C * sf_solution.sol_reduced;
        metrics.A_sfun   = A * sf_solution.sol_reduced;
        metrics.G_sfun   = G * sf_solution.sol_reduced;
        metrics.D_sfun   = D * sf_solution.sol_reduced;
        metrics.P_sfun   = P * sf_solution.sol_reduced / opts.grad_efficiency;
        metrics.T_sfun   = ( T * sf_solution.sol_reduced ).';
        metrics.TL_sfun  = ( TL * sf_solution.sol_reduced ).';
        metrics.F_sfun   = ( F * sf_solution.sol_reduced ).';
        metrics.FL_sfun  = ( FL * sf_solution.sol_reduced ).';
        metrics.W_sfun   = W * sf_solution.sol_reduced;

        % one value per P-matrix
        metrics.PNS_oracle     	= nan( n_P_matrices, n_P_bodyregions );
        metrics.PNS_thresh     	= nan( n_P_matrices, n_P_bodyregions );
        metrics.PNS_active      = nan( n_P_matrices, n_P_bodyregions );
        metrics.PNS_bmodel      = nan( n_P_matrices, 1 );
        if n_P_matrices > 0
            %if opts.use_P_constraint
            for nr = 1 : n_P_bodyregions
                for np = 1 : n_P_matrices
                    cur_mask    = P_constr_idx == np & P_bodyregion_idx == nr;

                    % index of body model
                    metrics.PNS_bmodel(np) = P_matrices{ cellfun( @(Pname) strcmpi( P_matrices{np,1}, Pname ), P_matrices(:,1) ), 4 };
                    
                    if all( opts.P_active(cur_mask) == 1 ) && any(cur_mask)
                        metrics.PNS_matrix_active( np,nr ) = 1;
                    elseif all( opts.P_active(cur_mask) == 0 )
                        metrics.PNS_matrix_active( np,nr ) = 0;
                    else
                        error('P-matrix constraints not defined correctly!')
                    end
                        
                    %pdi        = P_matrices{np,4};
                    %dset_name  = sf_design.P_matrix_dataset{np};
                    %H          = load( fullfile(ressources_dir, [dset_name, '.mat']), 'pnso_sparse' );
                
                    %PNSO_full  = H.pnso_sparse * ( P_mapping{np} * sf_solution.sol_full );
                    %max_full   = max(abs(PNSO_full)) / opts.grad_efficiency;
                    %max_comp   = max(abs( metrics.P_sfun( P_constr_idx == np ) ));
                
                    %rel_diff   = abs(max_full - max_comp) / max_comp;
                    %fprintf('  [check compression] P-matrix %d (%s): full = %.4f, compressed = %.4f, ecart = %.3f%%\n', ...
                        %np, P_matrices{np,1}, max_full, max_comp, 100*rel_diff)
                    %if rel_diff > 1e-4
                    %    warning('Ecart full/compresse pour %s (%.3f%%) : le pic PNSO peut etre sous-estime.', P_matrices{np,1}, 100*rel_diff)
                    %end

                    if all( cur_mask == 0 )
                        metrics.PNS_oracle( np,nr )  = 0;
                        metrics.PNS_thresh( np,nr )  = inf;
                    else
                        metrics.PNS_oracle( np,nr )  = max(abs(metrics.P_sfun( P_constr_idx == np & P_bodyregion_idx == nr )));
                        metrics.PNS_thresh( np,nr )  = 1 / metrics.PNS_oracle( np,nr );
                    end
                end
            end
        end
        if p == 1
           PNSO_cur_max = metrics.PNS_oracle( constr_pm_idx, : );
        end
        metrics.PNS_oracle_shift_plus  = rob_metric(Ps_gx_shift_plus,        P_shift_constr_idx,       double(x), opts.grad_efficiency);
        metrics.PNS_oracle_shift_minus = rob_metric(Ps_gx_shift_minus,       P_shift_constr_idx,       double(x), opts.grad_efficiency);
        metrics.PNS_oracle_tiltX_plus  = rob_metric(Ps_gx_angle_plus_theta,  P_angle_constr_idx_theta, double(x), opts.grad_efficiency);
        metrics.PNS_oracle_tiltX_minus = rob_metric(Ps_gx_angle_minus_theta, P_angle_constr_idx_theta, double(x), opts.grad_efficiency);
        % compute engineering metric terms from the descretized wire
        %------------------------------------------------------------

        % simulate inductance using FastHenry2
        [ metrics.wire_inductance, metrics.wire_resistance ]   = simulate_wire_inductance( sf_solution.wires, ressources_dir );

        % get wire torque and force
        if ~isempty( sf_design.b0 )
            metrics.wire_torque = calculate_wire_torque( sf_solution.wires, sf_design.b0, ressources_dir );
            metrics.wire_force  = calculate_wire_force( sf_solution.wires, sf_design.b0, ressources_dir );
        else
            metrics.wire_torque = [];
            metrics.wire_force  = [];  
        end

        % coil linearity
        %[ metrics.wire_sensitivity, metrics.wire_linearity, metrics.grad_type ] = get_gradient_linearity_from_wires( sf_solution.wires, sf_design.rol_radius, [], sf_design.encoding_component );
        metrics.wire_sensitivity    = [];
        metrics.wire_linearity      = [];
        metrics.grad_type           = [];
        
        % compute E-fields in homogeneous phantom (Roemer approach)
        %------------------------------------------------------------
        if true
            plot_male_phantom_Efields    = false;
            plot_female_phantom_Efields  = false;

            [ metrics.Ex_phantom_male, metrics.Ey_phantom_male, metrics.Ez_phantom_male ] = simulate_surface_electric_field( Male_phantom.node, Male_phantom.face, sf_solution.wires, 1.0, plot_male_phantom_Efields );
            metrics.Em_phantom_male = sqrt( metrics.Ex_phantom_male.^2 + metrics.Ey_phantom_male.^2 + metrics.Ez_phantom_male.^2 );

            % get max values in head and torso
            metrics.Em_phantom_male_max_head   = max( metrics.Em_phantom_male( Male_phantom.node(:,3) <= 0.1 ) );
            metrics.Em_phantom_male_max_torso  = max( metrics.Em_phantom_male( Male_phantom.node(:,3) > 0.1 ) );

            [ metrics.Ex_phantom_female, metrics.Ey_phantom_female, metrics.Ez_phantom_female ] = simulate_surface_electric_field( Female_phantom.node, Female_phantom.face, sf_solution.wires, 1.0, plot_female_phantom_Efields );
            metrics.Em_phantom_female = sqrt( metrics.Ex_phantom_female.^2 + metrics.Ey_phantom_female.^2 + metrics.Ez_phantom_female.^2 );

            % get max values in head and torso
            metrics.Em_phantom_female_max_head   = max( metrics.Em_phantom_female( Female_phantom.node(:,3) <= 0.1 ) );
            metrics.Em_phantom_female_max_torso  = max( metrics.Em_phantom_female( Female_phantom.node(:,3) > 0.1 ) );
        end

        % SAVE ALL METRICS
        sf_solution.metrics         = metrics;
        sf_solution.mosek_output    = output;
        
        fprintf('      ---------------- DESIGN -------------- \n')
        print_value_to_command( 'Gradient axis', metrics.grad_type )
        print_value_to_command( 'ROL radius [m]', metrics.rol_radius )
        print_value_to_command( 'Sensitivity [mT/m/A]', 1000 * metrics.sensitivity )
        print_value_to_command( 'Linearity [%]', 100*metrics.linearity )
%         fprintf('      -------------- STREAM FUN ------------ \n')
%         print_value_to_command( 'Torque X [Nm/A]', metrics.T_sfun(1) )
%         print_value_to_command( 'Torque Y [Nm/A]', metrics.T_sfun(2) )
%         print_value_to_command( 'Torque Z [Nm/A]', metrics.T_sfun(3) )
%         print_value_to_command( 'Force X [N/A]', metrics.F_sfun(1) )
%         print_value_to_command( 'Force Y [N/A]', metrics.F_sfun(2) )
%         print_value_to_command( 'Force Z [N/A]', metrics.F_sfun(3) )
%         print_value_to_command( 'ROL radius [m]', metrics.rol_radius )
%         print_value_to_command( 'Sensitivity [mT/m/A]', metrics.sensitivity )
%         print_value_to_command( 'Linearity [%]', 100*metrics.linearity )
        fprintf('      ----------------- WIRE --------------- \n')
        print_value_to_command( 'Sensitivity [mT/m/A]', 1000 * metrics.wire_sensitivity )
        print_value_to_command( 'Linearity [%]', 100 * metrics.wire_linearity )
        print_value_to_command( 'Inductance 1kHz [uH]', 1e+6*metrics.wire_inductance )
        print_value_to_command( '|Torque| [Nm/A]', norm( metrics.wire_torque ) )
        print_value_to_command( '|Force| [N/A]', norm( metrics.wire_force ) )
        for nr = 1 : n_P_bodyregions
            print_value_to_command( sprintf('PNS oracle (reg. %i) [m/T]',nr), metrics.PNS_oracle(:,nr) )
            print_value_to_command( sprintf('PNS thresh (reg. %i) [mT/m]',nr), 1000 * metrics.PNS_thresh(:,nr) )
        end

        % save all that stuff
        if p == 1
            save( save_name, 'sf_solution', 'P_nerves', 'P_nerves_full', 'P_sparse_rows', 'P_constr_idx', 'P_bodyregion_idx', 'P_matrices', 'output', 'alpha_shift', 'alpha_tilt', 'Pshift_branch' )
            % save( save_name; ... 
            %         's_opt', 's_min', 's_max', 'output', 'Bz_achieved', 'Bz_target', 'error_max', 'resistance_metric', 'torque_metric'; ...
            %         'inductance_metric', 'inductance_wire', 'max_edge_cdensity', 'pnso', 'max_pnso', 'lengths_wire', 'resistance_wire', 'wire_efficiency'; ...
            %         'torque_wire', 'C_max', 'T_max', 'P_max', 'D_max', 'wires', 'grad_average', 'grad_max_error', 'Bz_wires'; ...
            %         'pns_oracle_nerves', 'pns_comp_rows')
        else
            save( save_name, 'sf_solution', 'output', 'P_matrices' , 'alpha_shift', 'alpha_tilt', 'Pshift_branch')
            % save( save_name; ... 
            %         's_opt', 's_min', 's_max', 'output', 'Bz_achieved', 'Bz_target', 'error_max', 'resistance_metric', 'torque_metric'; ...
            %         'inductance_metric', 'inductance_wire', 'max_edge_cdensity', 'pnso', 'max_pnso', 'lengths_wire', 'resistance_wire', 'wire_efficiency'; ...
            %         'torque_wire', 'C_max', 'T_max', 'P_max', 'D_max', 'wires', 'grad_average', 'grad_max_error', 'Bz_wires' )
        end

    end
   
end

%exit()


function f = rob_family(name, M, grp, alpha)
    grp = grp(:);
    f = struct('name',name, 'M',M, 'grp',grp, 'groups',unique(grp), 'alpha',alpha, ...
               'act',false(size(M,1),1), 'ub',[], 'viol',[], 'eq',[], 'sgn',[]);
end

function r = rob_ref(v, idx, act, sel, n)
    r = nan(n,1);
    for np = sel(:).'
        r(np) = max(abs( v(idx==np & act) ));
    end
end

function r = rob_metric(M, grp, xv, geff)
    g = unique(grp);
    if isempty(M), r = nan(numel(g),1); return, end
    v = abs(M * xv);
    r = arrayfun(@(k) max(v(grp==k)), g) / geff;
end


function [xv, output, F] = lazy_solve(cons0, obj, x, F, mopts, tol, n_add, max_it)
    xv = [];  output = struct('problem',-1,'info','max_it');
    for it = 1:max_it
        cons = cons0;
        for k = 1:numel(F)
            a = F(k).act;
            if any(a)
                u = F(k).ub(a);  s = 1/max(u);
                cons = [cons, -s*u <= s*(F(k).M(a,:)*x) <= s*u];
            end
            if ~isempty(F(k).eq)
                ue = F(k).ub(F(k).eq);  se = 1/max(ue);
                cons = [cons, se*(F(k).sgn .* (F(k).M(F(k).eq,:)*x)) == se*ue];
            end
        end
        output = solvesdp(cons, obj, mopts);
        if output.problem ~= 0, return, end
        xv = double(x);
        n_new = 0;
        for k = 1:numel(F)
            v = abs(F(k).M * xv) ./ F(k).ub - 1;         % ub = inf -> -1
            F(k).viol = arrayfun(@(g) max(v(F(k).grp == g)), F(k).groups);
            v(F(k).act) = -inf;
            for g = 1:numel(F(k).groups)
                if F(k).viol(g) > tol
                    rows = find(F(k).grp == F(k).groups(g));
                    [vs, il] = maxk(v(rows), min(ceil(n_add/numel(F(k).groups)), numel(rows)));
                    il = il(vs > tol);
                    F(k).act(rows(il)) = true;
                    n_new = n_new + numel(il);
                end
            end
        end
        fprintf('    [lazy %d] %s | ajoutees: %d\n', it, ...
            strjoin(arrayfun(@(f) sprintf('%s:%d', f.name, nnz(f.act)), F, 'UniformOutput', false), ' '), n_new)
        if n_new == 0, return, end
    end
    warning('lazy_solve: max_it atteint'); output.problem = -1;
end