
% test_adaptive_simple.m
try
    img = imread('C:/Users/Golieth/.gemini/antigravity/brain/2bccbba7-9ba4-442d-9237-fee735f53403/uploaded_image_1767125912345.jpg');
    if size(img, 3) == 3, img = rgb2gray(img); end
    img = imresize(img, 0.1); % Tiny image
    
    fprintf('Testing Adaptive Threshold on tiny image...\n');
    bw = imbinarize(img, 'adaptive');
    fprintf('Adaptive Threshold Successful!\n');
    
    fprintf('Testing Adaptive Threshold with param...\n');
    bw2 = imbinarize(img, 'adaptive', 'Sensitivity', 0.5);
    fprintf('Adaptive Threshold with Param Successful!\n');
    
catch ME
    fprintf('ERROR: %s\n', ME.message);
end
