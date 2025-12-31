%% test_tuning_v4.m
imagePath = 'C:/Users/Golieth/.gemini/antigravity/brain/2bccbba7-9ba4-442d-9237-fee735f53403/uploaded_image_1767125912345.jpg';
img = imread(imagePath);
if size(img, 3) == 3, img = rgb2gray(img); end
img = imrotate(img, -90); % Fixed rotation

scales = [2.0, 3.0];
sensitivities = [0.5, 0.6];
sharpening = [false, true];

fid = fopen('tuning_results_v4.txt', 'w', 'n', 'UTF-8');

for s = scales
    % Resize
    I_scaled = imresize(img, s);
    
    for sharp = sharpening
        if sharp
            I_proc = imsharpen(I_scaled, 'Radius', 2, 'Amount', 1.5);
        else
            I_proc = I_scaled;
        end
        
        for sens = sensitivities
            fprintf(fid, '\n--- TEST: Scale=%.1f, Sharp=%d, Sens=%.2f ---\n', s, sharp, sens);
            
            % Adaptive Threshold
            % Text (Dark) -> Invert -> Text (Bright)
            I_inv = imcomplement(I_proc);
            bw = imbinarize(I_inv, 'adaptive', 'Sensitivity', sens);
            
            % Clean Noise
            bw = bwareaopen(bw, 10 * (s^2)); 
            
            % For OCR, Invert Back (Text Black, Bkg White)
            bwForOCR = ~bw; 
            
            bwUint8 = uint8(bwForOCR) * 255;
            
            try
                % Default Language (English)
                res = ocr(bwUint8);
                
                txt = strjoin(res.Words);
                fprintf(fid, 'Kelime Sayısı: %d\n', length(res.Words));
                
                % Check keywords (Normalization handled in checking)
                % Check for approximations
                if contains(txt, 'Gluten', 'IgnoreCase', true), fprintf(fid, '  [+] Gluten\n'); end
                if contains(txt, 'Sut', 'IgnoreCase', true) || contains(txt, 'Süt', 'IgnoreCase', true) || contains(txt, 'Sat', 'IgnoreCase', true), fprintf(fid, '  [+] Süt/Sut\n'); end
                if contains(txt, 'Yumurta', 'IgnoreCase', true) || contains(txt, 'Vumurta', 'IgnoreCase', true), fprintf(fid, '  [+] Yumurta\n'); end
                if contains(txt, 'Soya', 'IgnoreCase', true), fprintf(fid, '  [+] Soya\n'); end
                if contains(txt, 'Fistik', 'IgnoreCase', true) || contains(txt, 'Fistk', 'IgnoreCase', true), fprintf(fid, '  [+] Fistik\n'); end
                
                % Dump first 10 words
                for k = 1:min(length(res.Words), 10)
                     fprintf(fid, '  Word: %s\n', res.Words{k});
                end
                
            catch ME
                fprintf(fid, '  Hata: %s\n', ME.message);
            end
        end
    end
end
fclose(fid);
