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
            % Yön bulmak için daha önce hazırladığımız Kaliteli Adaptive (processedImg) görüntüyü kullanıyoruz.
            % Global Otsu (graythresh) düzensiz ışıkta başarısız olduğu için kaldırıldı.
            
            bwForRotation = processedImg;
            
            angles = [0, 90, 180, -90];
            bestAngle = 0;
            maxWords = -1;
            

                
            fprintf('Rotasyon taranıyor (Smart Anchor): ');
            
            % Oryantasyon bulmak için kritik kelimeler (Anchor Keywords)
            % Bu kelimelerin geçtiği açı kesinlikle doğru açıdır.
            anchors = {'icindekiler', 'enerji', 'protein', 'yag', 'doymus', ...
                       'karbonhidrat', 'seker', 'lif', 'tuz', 'besin', ...
                       'ogeleri', 'uretim', 'tarihi', 'tett', 'parti', ...
                       'mensei', 'turkiye', 'bol', 'serin', 'kuru', ...
                       'sut', 'soya', 'bugday', 'fistik', 'findik', 'eser'};
                   
            bestScore = -1;
            
            for angle = angles
                if angle == 0
                    tempImg = bwForRotation;
                else
                    % EMNİYET: Zemin kontrolü (yukarıdaki mantık)
                    if mean(bwForRotation(:)) > 0.5
                        tempImg = ~imrotate(~bwForRotation, angle);
                    else
                        tempImg = ~imrotate(~bwForRotation, angle); % Standardize
                    end
                end
                
                % Hızlı OCR
                try
                    res = ocr(tempImg, 'Language', 'turkish');
                catch
                    res = ocr(tempImg);
                end
                
                % Puanlama
                wordCount = 0;
                anchorHits = 0;
                
                for w = 1:length(res.Words)
                    txt = char(res.Words{w});
                    if length(txt) < 2, continue; end
                    
                    wordCount = wordCount + 1;
                    
                    % Kelimeyi temizle ve anchor kontrolü yap
                    cleanTxt = lower(txt);
                    cleanTxt = regexprep(cleanTxt, '[^a-z0-9]', '');
                    
                    if ismember(cleanTxt, anchors)
                        anchorHits = anchorHits + 1;
                    elseif contains(cleanTxt, 'icin') || contains(cleanTxt, 'ener')
                        anchorHits = anchorHits + 0.5; % Kısmi eşleşme puanı
                    end
                end
                
                % SKOR FONKSİYONU:
                % Anchor kelimeler çok değerli (x10 puan), normal kelimeler x1 puan.
                score = wordCount + (anchorHits * 20);
                
                fprintf('%d°->Score:%0.1f (W:%d, Key:%0.1f) | ', angle, score, wordCount, anchorHits);
                
                if score > bestScore
                    bestScore = score;
                    bestAngle = angle;
                end
            end
            fprintf('\nSeçilen Açı: %d derece (Skor: %.1f)\n', bestAngle, bestScore);
            
            % Seçilen açıya göre ASIL (Adaptive) görüntüyü döndür
            if bestAngle ~= 0
               if mean(processedImg(:)) > 0.5
                   % Beyaz Zemin
                   processedImg = ~imrotate(~processedImg, bestAngle);
               else
                   % Siyah Zemin
                   processedImg = imrotate(processedImg, bestAngle);
               end
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
            % Sadece Turkce degil, Ingilizce terimleri de yakalamak icin gelismis Matcher
            detected = struct('Word', {}, 'Category', {}, 'BBox', {}, 'Confidence', {});
            
            words = ocrResults.Words;
            boxes = ocrResults.WordBoundingBoxes;
            confs = ocrResults.WordConfidences;
            
            categories = fieldnames(obj.AllergenDB);
            
            % İngilizce -> Türk Kategorisi Eşleşmeleri (OCR İngilizce okursa diye)
            engMap = containers.Map();
            engMap('egg') = 'Yumurta';
            engMap('eggs') = 'Yumurta';
            engMap('milk') = 'Sut';
            engMap('gluten') = 'Gluten';
            engMap('wheat') = 'Gluten';
            engMap('flour') = 'Gluten';
            engMap('soy') = 'Soya';
            engMap('soya') = 'Soya';
            engMap('lecithin') = 'Soya'; % Genelde soya lesitini
            engMap('peanut') = 'Fistik';
            engMap('hazelnut') = 'Findik';
            engMap('walnut') = 'Ceviz';
            engMap('pistachio') = 'AntepFistigi';
            engMap('almond') = 'Badem';
            engMap('fish') = 'Balik';
            engMap('sesame') = 'Susam';
            engMap('mustard') = 'Hardal';
            engMap('celery') = 'Kereviz';
            engMap('cocoa') = 'Kakao';
            engMap('butter') = 'Sut';
            engMap('cream') = 'Sut';
            engMap('whey') = 'Sut';
            engMap('casein') = 'Sut';
            engMap('lactose') = 'Sut';
            engMap('sugar') = 'NiSastaVeSeker';
            engMap('salt') = 'Tuz'; % Tuz kategorisi yoksa 'BesinDegeri' vs.
            
            % Tehlikeli Kelimeler (False Positive karaliste)
            blacklist = {'sire', 'bade', 'kilo', 'gram', 'adet', 'tane', 'date', 'rate', 'food', 'good', 'net', 'yer', 'sade', 'bol', 'kal', 'cop', 'copu', 'kod'};
            
            % DEBUG: OCR Kelimelerini Konsola Dök
            fprintf('\n--- DEBUG: OCR DUMP (Smart Mode) ---\n');
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
                
                % 1. Temizlik (Punctuation removal)
                % "Lesitini)," -> "lesitini"
                clean = lower(raw);
                [~, normW] = fixTurkishCharacters(clean);
                
                % Sadece harfleri al, rakamlari da sil (gramaj karismasin)
                % Ancak e102 gibi kodlar onemli olabilir? Simdilik harf odaklanalim.
                normW = regexprep(normW, '[^a-z]', ''); 
                
                % Çok kısa kelimeleri atla
                if length(normW) < 3, continue; end 
                
                % Karaliste kontrolü
                if ismember(normW, blacklist), continue; end
                
                matchFound = false;
                
                % ÖZEL KURAL: İngilizce map kontrolü
                if isKey(engMap, normW)
                    targetCat = engMap(normW);
                    idx = length(detected) + 1;
                    detected(idx).Word = raw;
                    detected(idx).Category = targetCat; % Tr kategori ismi
                    detected(idx).BBox = boxes(i, :);
                    detected(idx).Confidence = confs(i);
                    matchFound = true;
                    % fprintf('    [ENG MATCH] %s -> %s\n', raw, targetCat);
                end
                
                if matchFound, continue; end
                
                % ÖZEL KURAL: "Glen" -> "Gluten" (Çok yaygın hata)
                if strcmp(normW, 'glen') || strcmp(normW, 'guten')
                     matchFound = true;
                     detected(end+1).Category = 'Gluten';
                     detected(end).Word = raw;
                     detected(end).BBox = boxes(i, :);
                     detected(end).Confidence = confs(i);
                     continue;
                end
                
                for c = 1:length(categories)
                    catName = categories{c};
                    catTerms = obj.AllergenDB.(catName);
                    
                    for t = 1:length(catTerms)
                        term = char(catTerms{t});
                        termLower = lower(term);
                        [~, termNorm] = fixTurkishCharacters(termLower);
                        termNorm = regexprep(termNorm, '[^a-z]', '');
                        
                        if length(termNorm) < 3, continue; end

                        isMatch = false;
                        
                        lenW = length(normW);
                        lenT = length(termNorm);

                        % A. Tam Eşleşme
                        if strcmp(normW, termNorm)
                            isMatch = true;
                        
                        % B. İçerme (Sadece uzun kelimeler için)
                        % "yerfistigi" icinde "fistik"
                        elseif contains(normW, termNorm) && lenT >= 4
                            isMatch = true;
                             
                        % C. SMARTER Adaptive Fuzzy
                        % Relaxed rules for missed items, strict for false positives.
                        elseif lenW >= 3 && lenT >= 3
                             if abs(lenW - lenT) > 2
                                 continue;
                             end

                             % Threshold hesabı
                             if lenT <= 4
                                 % Kısa kelimeler (3-4): 
                                 % 1 harf hatasına izin verelim MI? -> "Soy" vs "Soya" (4)
                                 % "Sut" vs "Su" (2) -> Riskli.
                                 % Ama "Soya" (4) vs "Soy" (3) -> %75 benzerlik.
                                 % "Fistik" (6)
                                 
                                 % KURAL: 4 harfli kelimeler için 1 harf eksik/yanlış kabul edelim (Sim > 0.70)
                                 % AMA sadece bilinen riskli olmayanlar için.
                                 threshold = 0.74; % 3/4=0.75 (ok), 2/3=0.66 (no)
                             elseif lenT <= 6
                                 % "Gluten" (6) vs "Glen" (4)? Dist=2. Sim=4/6=0.66 -> Yetmez.
                                 % "Gluten" (6) vs "Guten" (5)? Dist=1. Sim=5/6=0.83 -> OK.
                                 threshold = 0.80;
                             else
                                 threshold = 0.70;
                             end
                            
                            % Levenshtein Optimization
                            % Sadece ilk harf tutuyorsa hesapla (Hizlandirma)
                            if normW(1) == termNorm(1)
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
                categoryList = {};
                for k = 1:length(detected)
                    % Aynı kategoriyi tekrar tekrar yazmasın
                    key = [detected(k).Category '_' detected(k).Word];
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
