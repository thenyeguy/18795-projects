%
% 18-795 Project 2, Part 1
% Alex Sun Yoo (ayoo), Michael Nye (mnye), Ozan Iskilibli (oiskilib)
% Spring, 2014
%
% This file should run the demo for Part 1 by calling functions to perform
% each action and displaying results between steps
%

% Define constants
maskSize = 5;
plotting = true;

% Load our image files
disp 'Loading image files...'
imageFiles = dir('images/*.tif');
images = [];

% For testing purposes, only load first image
for ii = 1:1 %numel(imageFiles)
    image.name = imageFiles(ii).name;
    img = im2double(imread(['images/' image.name]));
    image.data = img / max(max(img));
    images = [images; image]; %#ok
end


%% B.2.1 Calibration of dark noise
disp 'Calibrating noise...'

% Manually crop a portion of background noise and determine its statistics.
% Choose an arbitrary image for this
img = images(ceil(numel(images)/2)).data;
[noiseMean, noiseStd] = calibrateBackground(img);


%% B.2.2 Detection of local maxima and local minima
disp 'Detecting minima and maxima...'

% First compute the sigma based on the numerical aperature
sigmaM = 0.61 * 527e-9 / 1.4; % .61*lambda/NA, in m
sigma  = sigmaM / 65e-9; % convert to pixels by dividing by pixel size

% For each image, find the extrema and store it
for ii = 1:numel(images)
    [maxima, minima] = findLocalExtrema(images(ii).data, maskSize, sigma);
    images(ii).maxima = maxima; %#ok
    images(ii).minima = minima; %#ok
end

% Display extrema of an arbitrary example
if plotting
    image = images(ceil(numel(images)/2));
    
    figure;
    imshow(image.data); hold on;
    scatter(images.minima(:,2), images.minima(:,1), 'g.');
    scatter(images.maxima(:,2), images.maxima(:,1), 'rx');
    legend('Minima', 'Maxima');
    title(sprintf('Raw extrema in image with %dx%d mask',maskSize,maskSize));
end



%% B.2.3 Establishing the local association of maxima and minima

% For each image, calculate delaunay triangulation
for ii = 1:numel(images)
    % Not sure if we do delaunay triangulation with combined minima+maxima?
    delaunay_tri = delaunay([images(ii).minima(:,2) ; images(ii).maxima(:,2)],...
        [images(ii).minima(:,1) ; images(ii).maxima(:,1)]);
    images(ii).delaunay = delaunay_tri;
end

%% Part B.2.4 Statistical selection of local maxima

