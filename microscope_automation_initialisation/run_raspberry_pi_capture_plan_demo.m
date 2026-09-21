clear;
clc;

rootDir = fileparts(mfilename('fullpath'));
addpath(rootDir);

config = fpm_default_config();
manifest = fpm_plan_raspberry_pi_sequence(config);

outputDir = fullfile(rootDir, 'output');
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

csvPath = fullfile(outputDir, 'raspberry_pi_capture_manifest.csv');
matPath = fullfile(outputDir, 'raspberry_pi_capture_manifest.mat');

writetable(manifest, csvPath);
save(matPath, 'manifest', 'config');

disp(['Saved capture manifest to ', csvPath]);
disp(['Saved capture manifest MAT file to ', matPath]);
disp(manifest(1:min(10, height(manifest)), :));
