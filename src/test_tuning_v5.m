%% test_tuning_v5.m
imagePath = 'C:/Users/Golieth/.gemini/antigravity/brain/2bccbba7-9ba4-442d-9237-fee735f53403/uploaded_image_1767125912345.jpg';
img = imread(imagePath);
if size(img, 3) == 3, img = rgb2gray(img); end
img = imrotate(img, -90); 

scales = [2.0];
sensitivities = [0.5, 0.6];
sharpening = [false]; % Simplify

fid = fopen('tuning_results_v5.txt', 'w', 'n', 'UTF-8');

for s = scales
    I_scaled = imresize(img, s);
    
    for sharp = sharpening
        if sharp
            I_proc = imsharpen(I_scaled, 'Radius', 2, 'Amount', 1.5);
        else
            I_proc = I_scaled;
        end
        
        for sens = sensitivities
            fprintf(fid, '\n--- TEST: Scale=%.1f, Sens=%.2f ---\n', s, sens);
            
            % Adaptive Threshold
            I_inv = imcomplement(I_proc);
            bw = imbinarize(I_inv, 'adaptive', 'Sensitivity', sens);
            bw = bwareaopen(bw, 10 * (s^2)); 
            
            bwForOCR = ~bw; 
            
            % SAVE IMAGE for inspection
            filename = sprintf('debug_tune_S%.1f_Sens%.2f.jpg', s, sens);
            imwrite(bwForOCR, filename);
            fprintf(fid, 'Saved %s\n', filename);
            
            bwUint8 = uint8(bwForOCR) * 255;
            
            try
                res = ocr(bwUint8); % English default
                
                txt = strjoin(res.Words);
                fprintf(fid, 'Words: %d\n', length(res.Words));
                
                if contains(txt, 'Gluten', 'IgnoreCase', true), fprintf(fid, ' [+] Gluten\n'); end
                if contains(txt, 'Sut', 'IgnoreCase', true) || contains(txt, 'Süt', 'IgnoreCase', true), fprintf(fid, ' [+] Süt\n'); end
                 if contains(txt, 'Yumurta', 'IgnoreCase', true), fprintf(fid, ' [+] Yumurta\n'); end
                 
            catch ME
                fprintf(fid, ' Error: %s\n', ME.message);
            end
        end
    end
end
fclose(fid);
