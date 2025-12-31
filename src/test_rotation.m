
% test_rotation.m
imagePath = 'C:/Users/Golieth/.gemini/antigravity/brain/2bccbba7-9ba4-442d-9237-fee735f53403/uploaded_image_1767125912345.jpg';
if ~exist(imagePath, 'file'), error('File not found'); end

% Preprocessing (Adaptive - proposed fix)
rawImg = imread(imagePath);
if size(rawImg, 3) == 3, gray = rgb2gray(rawImg); else, gray = rawImg; end

% Basic robust preprocessing
try, corrected = imflatfield(gray, 30); catch, corrected = gray; end
corrected = imadjust(corrected, stretchlim(corrected, [0.02 0.98]), []);
bw = imbinarize(corrected, 'adaptive', 'Sensitivity', 0.5);
if mean(bw(:)) < 0.5, bw = ~bw; end
bw = bwareaopen(bw, 30); % Clean noise

angles = [0, 90, -90, 180];

fprintf('--- Rotasyon Testi Basladi ---\n');

for angle = angles
    fprintf('\nRotasyon Acisi: %d derece\n', angle);
    
    if angle == 0
        rotImg = bw;
    else
        rotImg = imrotate(bw, angle);
    end
    
    try
        ocrRes = ocr(rotImg, 'Language', 'turkish');
    catch
        ocrRes = ocr(rotImg);
    end
    
    wordCount = length(ocrRes.Words);
    fprintf('  Bulunan Kelime Sayisi: %d\n', wordCount);
    
    if wordCount > 0
        fprintf('  Ornekler: %s\n', strjoin(ocrRes.Words(1:min(5, end)), ' '));
        
        foundAllergens = {};
        checkList = {'gluten', 'sut', 'süt', 'soya', 'fistik'};
        for w = 1:length(ocrRes.Words)
            word = lower(ocrRes.Words{w});
            for c = 1:length(checkList)
                if contains(word, checkList{c})
                    foundAllergens{end+1} = word;
                end
            end
        end
        if ~isempty(foundAllergens)
            fprintf('  BULUNAN ALERJEN ADAYLARI: %s\n', strjoin(unique(foundAllergens), ', '));
        else
            fprintf('  Alerjen bulunamadi.\n');
        end
    end
end
