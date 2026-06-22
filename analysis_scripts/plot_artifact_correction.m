clear all; close all; clc;
addpath(genpath(fullfile('..', 'functions')));

%% Config
session = 'Bert/BL_RW_003_Session_1';
[~, session_name] = fileparts(session);
[base_root, code_root, base_folder] = set_paths_cullen_lab(session);

metadata_csv  = fullfile(base_folder, 'Metadata',    [session_name, '_metadata.csv']);
summary_path  = fullfile(base_folder, 'Checkpoints', [session_name, '_summarized_metrics.mat']);
results_root  = fullfile(base_folder, 'results', 'checkpoints', 'sorting_results');

intan_folder  = fullfile(base_folder, 'Intan');
intan_folders_list = dir(intan_folder);
intan_folders_list = intan_folders_list([intan_folders_list.isdir] & ~startsWith({intan_folders_list.name}, '.'));
[~, sort_ord]      = sort({intan_folders_list.name});
intan_folders_list = intan_folders_list(sort_ord);

opts = detectImportOptions(metadata_csv);
opts = setvartype(opts, 'Stim_Delay', 'string');
T    = readtable(metadata_csv, opts);

%% Load conditions
% neural  = load('/Volumes/data/Current Project Databases - NHP/2025 Cerebellum prosthesis/Bert/BL_RW_003_Session_1/Intan/BL_closed_loop_STIM_003_250528_145904/neural_data_artifact_removed_pca.mat');
cal_file = load('/Volumes/data/Current Project Databases - NHP/2025 Cerebellum prosthesis/Bert/BL_RW_003_Session_1/Calibrated/IntanFile_5/BL_closed_loop_STIM_003_008_Cal_stim.mat');
spikes   = load('/Volumes/data/Current Project Databases - NHP/2025 Cerebellum prosthesis/Bert/BL_RW_003_Session_1/results/checkpoints/sorting_results/BL_closed_loop_STIM_003_250528_145904/NPRW/spike_trains.mat');
%%
unit_spike_train_name = 'unit_138';
unit_spike_train = spikes.(unit_spike_train_name);