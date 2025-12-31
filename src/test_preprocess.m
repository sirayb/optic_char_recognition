
% test_preprocess.m
imagePath = 'C:/Users/Golieth/.gemini/antigravity/brain/2bccbba7-9ba4-442d-9237-fee735f53403/uploaded_image_1767125912345.jpg';
if ~exist(imagePath, 'file'), error('File not found'); end
rawImg = imread(imagePath);
if size(rawImg, 3) == 3, gray = rgb2gray(rawImg); else, gray = rawImg; end

methods = {'Otsu+Flat', 'Adaptive+Flat', 'OtsuOnly', 'AdaptiveOnly'};
results = struct();

fprintf('--- Preprocessing Metodlari Test Ediliyor ---\n');

for i = 1:4
    methodName = methods{i};
    fprintf('\nMetod: %s\n', methodName);
    
    % 1. Preprocess
    img = gray;
    
    % Flatfield
    if contains(methodName, 'Flat')
        try, img = imflatfield(img, 30); catch, end
    end
    
    % Contrast
    img = imadjust(img, stretchlim(img, [0.02 0.98]), []);
    
    % Threshold
    if contains(methodName, 'Otsu')
        level = graythresh(img);
        bw = imbinarize(img, level);
    else
        bw = imbinarize(img, 'adaptive', 'Sensitivity', 0.5);
    end
    
    % Polarity
    if mean(bw(:)) < 0.5, bw = ~bw; end
    
    % Noise removal - Adaptive produces more noise, so use higher value
    if contains(methodName, 'Adaptive')
        bw = bwareaopen(bw, 50);
    else
        bw = bwareaopen(bw, 15);
    end
    
    fprintf('  Goruntu Boyutu: %dx%d\n', size(bw, 1), size(bw, 2));
    
    % 2. OCR (Sadece 1.0x ölçekte hızlı test)
    try
        try
            ocrRes = ocr(bw, 'Language', 'turkish');
        catch
            ocrRes = ocr(bw);
        end
        wordCount = length(ocrRes.Words);
        confs = ocrRes.WordConfidences;
        avgConf = mean(confs);
        textSample = strjoin(ocrRes.Words(1:min(5, end)), ' ');
        
        fprintf('  Kelime Sayisi: %d\n', wordCount);
        fprintf('  Ort. Guven: %.2f\n', avgConf);
        fprintf('  Ornek Metin: %s\n', textSample);
        
        % Alerjen kelime kontrolü
        foundSut = any(contains(lower(ocrRes.Words), 'sut') | contains(lower(ocrRes.Words), 'süt'));
        foundGluten = any(contains(lower(ocrRes.Words), 'gluten'));
        
        fprintf('  "Süt" bulundu mu?: %d\n', foundSut);
        fprintf('  "Gluten" bulundu mu?: %d\n', foundGluten);
        
    catch ME
        fprintf('  HATA: %s\n', ME.message);
    end
end
