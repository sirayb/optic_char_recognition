%% test_tuning_v3.m
imagePath = 'C:/Users/Golieth/.gemini/antigravity/brain/2bccbba7-9ba4-442d-9237-fee735f53403/uploaded_image_1767125912345.jpg';
img = imread(imagePath);
if size(img, 3) == 3, img = rgb2gray(img); end
img = imrotate(img, -90); % Fixed rotation

scales = [2.0, 3.0];
sensitivities = [0.5, 0.6];
sharpening = [false, true];

fid = fopen('tuning_results_v3.txt', 'w', 'n', 'UTF-8');

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
            % ForegroundIsDark = true (Text is black)
            % imbinarize with adaptive assumes foreground is brighter by default? 
            % 'ForegroundPolarity','dark' is available in recent versions, else use complement.
            % Let's use complement to be safe.
            % Text (Dark) -> Invert -> Text (Bright)
            I_inv = imcomplement(I_proc);
            bw = imbinarize(I_inv, 'adaptive', 'Sensitivity', sens);
            % Now Text is 1 (White), Bkg is 0 (Black).
            
            % Clean Noise (White dots on black background)
            bw = bwareaopen(bw, 10 * (s^2)); 
            
            % For OCR, Tesseract prefers Black Text on White Background.
            % So INVERT BACK.
            bwForOCR = ~bw; 
            % Now Text is 0 (Black), Bkg is 1 (White).
            
            bwUint8 = uint8(bwForOCR) * 255;
            
            try
                res = ocr(bwUint8, 'Language', 'turkish');
                
                txt = strjoin(res.Words);
                fprintf(fid, 'Kelime Sayısı: %d\n', length(res.Words));
                
                % Check keywords
                if contains(txt, 'Gluten', 'IgnoreCase', true), fprintf(fid, '  [+] Gluten\n'); end
                if contains(txt, 'Sut', 'IgnoreCase', true) || contains(txt, 'Süt', 'IgnoreCase', true), fprintf(fid, '  [+] Süt\n'); end
                if contains(txt, 'Yumurta', 'IgnoreCase', true), fprintf(fid, '  [+] Yumurta\n'); end
                if contains(txt, 'Soya', 'IgnoreCase', true), fprintf(fid, '  [+] Soya\n'); end
                
                % Dump first 5 words
                for k = 1:min(length(res.Words), 5)
                     fprintf(fid, '  Word: %s\n', res.Words{k});
                end
                
            catch ME
                fprintf(fid, '  Hata: %s\n', ME.message);
            end
        end
    end
end
fclose(fid);
