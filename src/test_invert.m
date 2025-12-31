%% test_invert.m
detector = AllergenDetector();
imagePath = 'C:/Users/Golieth/.gemini/antigravity/brain/2bccbba7-9ba4-442d-9237-fee735f53403/uploaded_image_1767125912345.jpg';

% 1. Preprocess (Standard) inside detector
% Access internal method if possible? No, private.
% Re-implement simplified version here for test.

img = imread(imagePath);
if size(img, 3) == 3, img = rgb2gray(img); end
img = imrotate(img, -90); % We know this is best

% Emulate preprocessImage logic
img = imresize(img, 2.0); % Scale 2.0
img = imflatfield(img, 30);
img = imadjust(img);
bw = imbinarize(img, 'adaptive', 'Sensitivity', 0.5);
bw = medfilt2(bw, [3 3]);
bw = bwareaopen(bw, 30);

% Ensure White Text on Black Background (Current Logic)
if mean(bw(:)) > 0.5
    bw_WhiteText = ~bw;
else
    bw_WhiteText = bw;
end
bw_BlackText = ~bw_WhiteText;

fprintf('--- OCR INVERSION TEST ---\n');

% TEST 1: Current (White Text on Black)
try
    res1 = ocr(bw_WhiteText);
    fprintf('1. White Text (Current): %d words\n', length(res1.Words));
    if length(res1.Words) > 0
        fprintf('   First 5: %s\n', strjoin(res1.Words(1:min(5, end))));
    end
    txt1 = strjoin(res1.Words);
    if contains(txt1, 'Sut', 'IgnoreCase',true), fprintf('   [+] Found Sut\n'); end
catch ME
    fprintf('1. Error: %s\n', ME.message);
end

% TEST 2: Inverted (Black Text on White)
try
    res2 = ocr(bw_BlackText);
    fprintf('2. Black Text (Inverted): %d words\n', length(res2.Words));
    if length(res2.Words) > 0
        fprintf('   First 5: %s\n', strjoin(res2.Words(1:min(5, end))));
    end
    txt2 = strjoin(res2.Words);
    if contains(txt2, 'Sut', 'IgnoreCase',true), fprintf('   [+] Found Sut\n'); end
catch ME
    fprintf('2. Error: %s\n', ME.message);
end
