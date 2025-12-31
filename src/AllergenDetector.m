classdef AllergenDetector < handle
    % AllergenDetector - Gıda paketlerindeki alerjenleri tespit eden ana sınıf.
    % Tüm boru hattını (Preprocessing, OCR, Matching, Visualization) yönetir.

    properties
        AllergenDB          % Alerjen veritabanı (struct)
        Config              % Yapılandırma parametreleri
    end

    methods
        function obj = AllergenDetector()
            % Constructor - Veritabanını yükle ve yapılandırmayı ayarla
            obj.AllergenDB = createAllergenDatabase();
            obj.Config.MinSimilarity = 0.85; % Bulanık eşleşme eşiği
            obj.Config.MinWordLength = 3;    % Minimum kelime uzunluğu
        end

        function [annotatedImg, detected, ocrResults] = processImage(obj, imagePath)
            % 1. Dosya Okuma
            if ischar(imagePath) || isstring(imagePath)
                rawImg = imread(imagePath);
            else
                rawImg = imagePath;
            end

            % 2. Preprocessing (Önişleme)
            % Mevcut preprocessImage.m mantığını kullanır
            processedImg = obj.preprocess(rawImg);

            % 3. Rotasyon Taraması (Hibrit Yaklaşım)
            % Yön bulmak için Hızlı Otsu kullan, okuma için Kaliteli Adaptive kullan.
            % Otsu, yön tespiti için daha hızlı ve genellikle yeterlidir.
            
            % Geçici Otsu görüntüsü oluştur (sadece yön bulma için)
            % Not: processImage başında rawImg var.
            grayForOtsu = rawImg;
            if size(grayForOtsu, 3) == 3, grayForOtsu = rgb2gray(grayForOtsu); end
            grayForOtsu = imadjust(grayForOtsu, stretchlim(grayForOtsu, [0.02 0.98]), []);
            lvl = graythresh(grayForOtsu);
            otsuBw = imbinarize(grayForOtsu, lvl);
            if mean(otsuBw(:)) < 0.5, otsuBw = ~otsuBw; end % Polarite düzelt
            otsuBw = bwareaopen(otsuBw, 15);

            angles = [0, 90, 180, -90];
            bestAngle = 0;
            maxWords = -1;
            
            fprintf('Rotasyon taranıyor (Otsu ile): ');
            for angle = angles
                if angle == 0
                    tempImg = otsuBw;
                else
                    % Padding düzeltmesi (Invert-Rotate-Invert)
                    tempImg = ~imrotate(~otsuBw, angle);
                end
                
                % Hızlı OCR
                try
                    res = ocr(tempImg, 'Language', 'turkish');
                catch
                    res = ocr(tempImg);
                end
                
                try % Wrap the OCR and word counting in a try-catch
                    if angle == 0
                        tempImg = otsuBw;
                    else
                        % Padding düzeltmesi (Invert-Rotate-Invert)
                        tempImg = ~imrotate(~otsuBw, angle);
                    end
                    
                    % Hızlı OCR
                    try
                        res = ocr(tempImg, 'Language', 'turkish');
                    catch
                        res = ocr(tempImg);
                    end
                    
                    % Geçerli kelime sayısı
                    validWords = 0;
                    for w = 1:length(res.Words)
                        if length(res.Words{w}) >= 3
                            validWords = validWords + 1;
                        end
                    end
                    
                    fprintf('%d°->%d kelime | ', angle, validWords);
                    
                    if validWords > maxWords
                        maxWords = validWords;
                        bestAngle = angle;
                    end
                catch ME
                    % fprintf('Error during rotation %d: %s\n', angle, ME.message);
                    fprintf('%d°->HATA | ', angle);
                    continue; % Skip to the next angle if an error occurs
                end
            end
            fprintf('\nSeçilen Açı: %d derece\n', bestAngle);
            
            % Seçilen açıya göre ASIL (Adaptive) görüntüyü döndür
            if bestAngle ~= 0
               % Padding sorunu olmasın diye Invert -> Rotate -> Invert
               processedImg = ~imrotate(~processedImg, bestAngle); 
               rawImg = imrotate(rawImg, bestAngle);
            end

            % 4. Multi-scale OCR (Detaylı Tarama)
            % extractTextAdvanced [words, boxes, confs] döndürür.
            % Bunu ocrResults struct yapısına dönüştürmeliyiz.
            % 4. Multi-scale OCR (Detaylı Tarama)
            % extractTextAdvanced doğrudan ocrResults struct döndürüyor.
            % [ocrResults, allWords, allBoxes] = extractTextAdvanced...
            [ocrResults, ~, ~] = extractTextAdvanced(processedImg);
            
            % ocrResults zaten yapılandırılmış durumda (Words, Boxes, Confidences)
            
            % Rotasyon düzeltmesi varsa rawImg döndür (görselleştirme için)
            % Not: Yukarıda rawImg zaten döndürüldü (Line 105), burada tekrar döndürmeye gerek YOK.
            % Line 105'teki rawImg dönüşümü kalıcıdır ve görselleştirmede kullanılır.
            
            % 5. Alerjen Eşleştirme (Matching)
            detected = obj.matchAllergens(ocrResults);

            % 6. Görselleştirme (Visualization)
            annotatedImg = obj.visualize(rawImg, ocrResults, detected);
        end
    end

    methods (Access = private)
        function bw = preprocess(~, img)
            % Gri tonlama -> Kontrast Artırma -> Adaptive Binarization
            if size(img, 3) == 3, gray = rgb2gray(img); else, gray = img; end
            
            % Işık dengeleme
            try
                corrected = imflatfield(gray, 30);
            catch
                corrected = gray; % imflatfield yoksa atla
            end
            
            % Keskinleştirme (Yeni: Blur temizliği için)
            corrected = imsharpen(corrected, 'Radius', 1, 'Amount', 1.5);
            
            % Kontrast germe
            corrected = imadjust(corrected, stretchlim(corrected, [0.02 0.98]), []);
            
            % Adaptive Thresholding (Otsu yerine)
            % Işık dalgalanmalarına karşı daha dirençli
            bw = imbinarize(corrected, 'adaptive', 'Sensitivity', 0.5);
            
            % Gürültü Temizleme (Median Filter) - Tuz-biber gürültüsünü siler
            bw = medfilt2(bw, [3 3]);

            % Polarite kontrolü (Zemin beyaz olmalı)
            if mean(bw(:)) < 0.5, bw = ~bw; end
            
            % Küçük gürültü temizleme (Biraz artırıldı)
            bw = bwareaopen(bw, 30);
        end

    end
    methods (Access = public) % Test edilebilir olması için public yapıldı
        function detected = matchAllergens(obj, ocrResults)
            % Basitleştirilmiş ve Ipuçlu Matcher
            detected = struct('Word', {}, 'Category', {}, 'BBox', {}, 'Confidence', {});
            
            words = ocrResults.Words;
            boxes = ocrResults.WordBoundingBoxes;
            confs = ocrResults.WordConfidences;
            
            categories = fieldnames(obj.AllergenDB);
            
            % DEBUG: OCR Kelimelerini Konsola Dök
            fprintf('\n--- DEBUG: OCR DUMP (Ilk 100 kelime) ---\n');
            fprintf('Algılanan toplam kelime sayısı: %d\n', length(words));
            debugStr = '';
            for k=1:min(length(words), 100)
               try
                   if iscell(words), wRaw = char(words{k});
                   elseif isstring(words), wRaw = char(words(k));
                   else, wRaw = char(words(k,:)); end
                   debugStr = [debugStr ' [' wRaw ']'];
               catch
               end
               if mod(k, 10) == 0, debugStr = [debugStr '\n']; end
            end
            fprintf('%s\n', debugStr);
            fprintf('---------------------------------------\n');
            
            for i = 1:length(words)
                try
                    if iscell(words), raw = char(words{i});
                    elseif isstring(words), raw = char(words(i));
                    else, raw = char(words(i,:)); end
                catch
                    continue;
                end
                
                % 2. Temizle
                clean = lower(raw);
                [~, normW] = fixTurkishCharacters(clean);
                normW = regexprep(normW, '[^a-z0-9]', '');
                
                % Çok kısa kelimeleri atla
                if length(normW) < 2, continue; end 
                
                matchFound = false;
                
                for c = 1:length(categories)
                    catName = categories{c};
                    catTerms = obj.AllergenDB.(catName);
                    
                    for t = 1:length(catTerms)
                        term = char(catTerms{t});
                        termLower = lower(term);
                        [~, termNorm] = fixTurkishCharacters(termLower);
                        termNorm = regexprep(termNorm, '[^a-z0-9]', '');
                        
                        isMatch = false;
                        
                        lenW = length(normW);
                        lenT = length(termNorm);

                        % A. Tam Eşleşme (Her zaman kabul)
                        if strcmp(normW, termNorm)
                            isMatch = true;
                        
                        % B. İçerme (Sadece uzun kelimeler için)
                        elseif contains(normW, termNorm) && lenT >= 5
                            isMatch = true;
                            
                        % C. Adaptive Fuzzy (Bulanık) Eşleşme
                        elseif lenW >= 3 && lenT >= 3
                             % Eşik belirle
                             if lenT < 6
                                 % Kısa kelimeler (3-5 harf): TAM EŞLEŞME ZORUNLU
                                 % "Sire" (4) -> "Sirke" (5) hatasını %100 önlemek için.
                                 % "Bade" -> "Badem" de yakalanmayacak ama False Positive azalacak.
                                 threshold = 1.0; 
                             elseif lenT < 8
                                 % Orta uzunluk (6-7): %85 (max 1 harf hatası)
                                 threshold = 0.85;
                             else
                                 % Uzun kelimeler: %70
                                 threshold = 0.70;
                             end
                            
                             if abs(lenW - lenT) > 2
                                 continue;
                             end

                             % Threshold 1.0 ise Levenshtein hesaplamaya gerek yok
                             if threshold < 1.0
                                try
                                    dist = obj.levenshtein(normW, termNorm);
                                    sim = 1 - (dist / max(lenW, lenT));
                                    
                                    if sim >= threshold
                                        isMatch = true;
                                    end
                                catch
                                end
                             end
                        end
                        
                        if isMatch
                            idx = length(detected) + 1;
                            detected(idx).Word = raw;
                            detected(idx).Category = catName;
                            detected(idx).BBox = boxes(i, :);
                            detected(idx).Confidence = confs(i);
                            matchFound = true;
                            break; 
                        end
                    end
                    if matchFound, break; end
                end
            end
            
            % Struct yapısını düzelt
            if isempty(detected)
                 detected = struct('Word', {}, 'Category', {}, 'BBox', {}, 'Confidence', {});
            end
            
            % Sonuç Raporu
            fprintf('\n--- TESPIT RAPORU ---\n');
            if isempty(detected)
                fprintf('  [!] Temiz. Herhangi bir alerjen bulunamadi.\n');
            else
                fprintf('  [!] DIKKAT! %d adet alerjen tespit edildi:\n', length(detected));
                for k = 1:length(detected)
                    fprintf('    -> %s (Bulunan: "%s")\n', upper(detected(k).Category), detected(k).Word);
                end
            end
            fprintf('---------------------\n');
        end


        function annotated = visualize(~, baseImg, ~, detected)
            annotated = baseImg;
            if isempty(detected), return; end
            
            try
                fs = 24; % Font Size
                % Gerekli değişkenleri hazırla
                bboxes = reshape([detected.BBox], 4, [])';
                labels = upper({detected.Category}); % Kategori ismini göster (SUT, GLUTEN vs.) 
                
                % Etiket pozisyonu
                labelPos = bboxes(:, 1:2);
                labelPos(:,2) = max(1, labelPos(:,2) - 20); 
                
                % Kutuları çiz
                annotated = insertShape(annotated, 'Rectangle', bboxes, 'LineWidth', 3, 'Color', 'red');
                
                annotated = insertText(annotated, labelPos, labels, ...
                    'FontSize', fs, 'BoxColor', 'red', 'BoxOpacity', 0.5, ...
                    'TextColor', 'white', 'AnchorPoint', 'LeftBottom', 'Font', 'Arial Bold');
            catch ME
                fprintf('  [!] Visualize Hatasi: %s\n', ME.message);
            end
        end
        
        function d = levenshtein(~, s1, s2)
            % fprintf('Levenshtein called: "%s" vs "%s"\n', s1, s2);
            try
                n = length(s1); m = length(s2);
                d = zeros(n+1, m+1);
                d(:,1) = 0:n; d(1,:) = 0:m;
                for i = 1:n
                    for j = 1:m
                        cost = ~strcmp(s1(i), s2(j));
                        d(i+1, j+1) = min([d(i, j+1)+1, d(i+1, j)+1, d(i, j)+cost]);
                    end
                end
                d = d(n+1, m+1);
            catch ME
                fprintf('Levenshtein Internal Error: %s\n', ME.message);
                d = 999;
            end
        end
    end
end
