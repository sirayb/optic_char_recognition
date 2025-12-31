%% test_tuning.m
imagePath = 'C:/Users/Golieth/.gemini/antigravity/brain/2bccbba7-9ba4-442d-9237-fee735f53403/uploaded_image_1767125912345.jpg';
img = imread(imagePath);
if size(img, 3) == 3, img = rgb2gray(img); end

% Rotate -90 (User config)
img = imrotate(img, -90);

% Test Parameters
scales = [2.0, 3.0];
sensitivities = [0.4, 0.5, 0.6];

for s = scales
    for sens = sensitivities
        fprintf('\n--- TEST: Scale=%.1f, Sensitivity=%.2f ---\n', s, sens);
        
        % 1. Resize
        I = imresize(img, s);
        
        % 2. Contrast Enhancement (Adjust)
        I = imadjust(I);
        
        % 3. Sharpen (New!)
        I = imsharpen(I);
        
        % 4. Binarize
        bw = imbinarize(I, 'adaptive', 'Sensitivity', sens);
        
        % 5. Denoise
        bw = medfilt2(bw, [3 3]);
        bw = bwareaopen(bw, 10 * (s^2)); % Dynamic area filter
        
        % Convert to uint8 for OCR
        bwUint8 = uint8(bw) * 255;
        
        % 6. OCR
        try
            % Try with Turkish first
            try
                 res = ocr(bwUint8, 'Language', 'turkish');
            catch
                 % Fallback
                 res = ocr(bwUint8);
            end
            fprintf('Kelime Sayısı: %d\n', length(res.Words));
            
            % Print first 10 words
            for k = 1:min(length(res.Words), 10)
                 fprintf('  %s\n', res.Words{k});
            end
            
            % Check specific keywords
            txt = strjoin(res.Words);
            if contains(txt, 'Gluten', 'IgnoreCase', true), fprintf('  [+] Gluten bulundu\n'); end
            if contains(txt, 'Sut', 'IgnoreCase', true) || contains(txt, 'Süt', 'IgnoreCase', true), fprintf('  [+] Sut bulundu\n'); end
            if contains(txt, 'Yumurta', 'IgnoreCase', true), fprintf('  [+] Yumurta bulundu\n'); end
            
        catch ME
            fprintf('  Hata: %s\n', ME.message);
        end
    end
end
