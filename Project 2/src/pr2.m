%
% 18-795 Project 2
% Alex Sun Yoo (ayoo), Michael Nye (mnye), Ozan Iskilibli (oiskilib)
% Spring, 2014
%
% This file should run the demo for project 2 by calling functions to 
% perform each action and displaying results between steps
%

% Clean up
clear all
close all
clc

% Create a clean directory for output
if exist('../mat_files','dir')
    rmdir('../mat_files', 's');
end
mkdir('../mat_files');

% Define constants
maskSize = 3;
plotting = true;

% Rayleigh limit
rayleighM = 0.61 * 527e-9 / 1.4; % .61*lambda/NA, in m
rayleigh  = rayleighM / 65e-9; % convert to pixels

% Load our image files
disp 'Loading image files...'
imageFiles = dir('../images/*.tif');
images = [];

Nimages = numel(imageFiles);
Nimages = 1;

for ii = 1:Nimages
    image.name = imageFiles(ii).name;
    img = im2double(imread(['../images/' image.name]));
    image.data = img / max(max(img));
    images = [images; image]; %#ok
end
clear img;


%% B.2.1 Calibration of dark noise
disp 'Calibrating noise...'

% Manually crop a portion of background noise and determine its statistics.
% Choose an arbitrary image for this
[noiseMean, noiseStd] = calibrateBackground(images(1).data);


%% B.2.2 Detection of local maxima and local minima
disp 'Detecting minima and maxima...'

% First compute the sigma based on the rayleigh limit
sigma = rayleigh/3;

% For each image, find the extrema and store it
for ii = 1:Nimages
    [images(ii).allMaxima, images(ii).allMinima] = ...
        findLocalExtrema(images(ii).data, maskSize, sigma); %#ok
end

% Display extrema of an arbitrary example
if plotting
    image = images(1);
    
    figure;
    imshow(image.data); hold on;
    scatter(images.allMinima(:,2), images.allMinima(:,1), 'g.');
    scatter(images.allMaxima(:,2), images.allMaxima(:,1), 'rx');
    legend('Minima', 'Maxima');
    title(sprintf('Raw extrema in image with %dx%d mask',maskSize,maskSize));
end

clear image sigma;


%% B.2.3 Establishing the local association of maxima and minima
disp 'Associating maximas to minimas using Delaunay Triangulation...'

% For each image, calculate delaunay triangulation
for ii = 1:Nimages
    [images(ii).associated visual] = assocLocalExt(images(ii)); %#ok
end

if plotting
    imageIndex = ceil(numel(images)/2);
    image = images(imageIndex);
    tmp = size(image.associated.triAddr,2);
    tmpLocalMax = [];
    for ii = 1:tmp;
        tmpLocalMax = [tmpLocalMax; images.associated.LocalMaxAddr{ii}]; %#ok
    end
   
    figure;
    imshow(image.data); hold on;
    h1 = triplot(visual, 'b');
    h2 = scatter(tmpLocalMax(:,2), tmpLocalMax(:,1), 'rx');
    legend([h1(1) h2], {'Delaunay triangles', 'Maxima'});
    title('Delaunay Triangulation');
end

clear visual imageIndex image tmp tmpLocalmax;


%% Part B.2.4 Statistical selection of local maxima
disp 'Statistically detecting maximas...'

Quantile = 10;
for ii = 1:Nimages
    [images(ii).maxima] = ...
        statMaxima(images(ii), Quantile, noiseMean, noiseStd);%#ok
end

% Display extrema of an arbitrary example
if plotting
    image = images(1);
    figure;
    imshow(image.data); hold on;
    scatter(images(1).maxima(:,2), images(1).maxima(:,1), 'rx');
    legend('Statistically selected maxima');
    title(['Statistically selected maximas for Q=' num2str(Quantile) ...
        ', \sigma_\Delta_I=' num2str(noiseStd/sqrt(3))]);
end

% Storing the processed image

% Store
for ii = 1:Nimages
    path = ['../mat_files/' images(ii).name(1:end-4) '_statistical_maxima.mat'];
    imageIndex = ii;
    maxima = images(ii).maxima; %#ok stored below
    save(path, 'imageIndex', 'maxima');
end
clear Quantile image path maxima;


%% Part B.3.1 Generating Synthetic Images
disp 'Generating synthetic image...'

% Use first image - divide by two for radius
sigma = rayleigh/2;
syntheticImage = generateSyntheticImage(images(1), sigma, ...
    noiseMean, noiseStd);

if plotting
    figure;
    subplot(2,1,1), imagesc(syntheticImage), title('Synthetic image');
    colormap gray, axis image;
    subplot(2,1,2), imagesc(images(1).data), title('Actual image');
    colormap gray, axis image;
end

clear sigma;


%% Part B.3.2 Sub pixel resolution detection using oversampling

disp 'Detecting sub-pixel particles using Gaussian fitting...'

% Sub-pixel particle detection using Gaussian Kernel Fitting Algorithm
% on each image in the sequence
for ii = 1:Nimages
    images(ii).subpixelMaxima = subpixelGaussianFit(images(ii),rayleigh,5); %#ok
end

% Show the particles on the image
if plotting
    figure; hold on;
    imshow(images(ii).data);
    scatter(images(1).subpixelMaxima(:,2),...
        images(1).subpixelMaxima(:,1), 'rx');
    title('Subpixel Detection using Gaussian Fit, actual data')
    legend('Sub-pixel Detected Particles');   
end

% Store
for ii = 1:Nimages
    path = ['../mat_files/' images(ii).name(1:end-4) '_subpixel_maxima.mat'];
    imageIndex = ii;
    maxima = images(ii).subpixelMaxima; %#ok stored below
    save(path, 'imageIndex', 'maxima');
end
clear maxima;


%% Part B.3.3 Benchmarking subpixel resolution particle detection
disp 'Benchmarking subpixel performance using synthetic image...'

% First perform subpixel detection on the synthetic image
synthetic.data = syntheticImage;
synthetic.maxima = images(1).maxima;
syntheticMaxima = subpixelGaussianFit(synthetic,rayleigh,5);

% For each maxima, find its nearest maxima and compute the error distance
errors = [];
image = images(1);
for ii = 1:size(syntheticMaxima,1)
    maximum = syntheticMaxima(ii,:);
    
    lowestError = [Inf Inf];
    lowestDistance = Inf;
    for jj = 1:size(image.maxima,1)
        error = maximum - image.maxima(jj,:);
        distance = norm(error);
        if distance < lowestDistance
            lowestError = error;
            lowestDistance = distance;
        end
    end
    
    errors = [errors; lowestError]; %#ok append
end

% Show the particles on the image
if plotting
    figure; hold on;
    imshow(syntheticImage);
    scatter(syntheticMaxima(:,2), syntheticMaxima(:,1), 'rx');
    title('Subpixel Detection using Gaussian Fit, synthetic data')
    legend('Sub-pixel Detected Particles');   
end

% Compute the statistics and display
errorMean = mean(errors);
errorStd = std(errors);

disp(['    Subpixel detection had an average (y,x) error of:  ' ...
    num2str(errorMean)]);
disp(['    and a (y,x) standard deviation of:                 ' ...
    num2str(errorStd)]);

%clear synthetic errors image maximum lowestDistance distance;
