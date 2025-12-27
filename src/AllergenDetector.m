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

        function [annotatedImg, detected] = processImage(obj, imagePath)
            % 1. Dosya Okuma
            if ischar(imagePath) || isstring(imagePath)
                rawImg = imread(imagePath);
            else
                rawImg = imagePath;
            end

            % 2. Preprocessing (Önişleme)
            % Mevcut preprocessImage.m mantığını kullanır
            processedImg = obj.preprocess(rawImg);

            % 3. Multi-scale OCR
            % extractTextAdvanced.m fonksiyonunu kullanır
            [ocrResults, ~, ~] = extractTextAdvanced(processedImg);

            % 4. Alerjen Eşleştirme (Matching)
            detected = obj.matchAllergens(ocrResults);

            % 5. Görselleştirme (Visualization)
            % visualizeAllergens.m mantığını kullanır
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
            % Kontrast germe
            corrected = imadjust(corrected, stretchlim(corrected, [0.02 0.98]), []);
            % Binarize (Otsu - Daha önce çalışan kararlı sürüme geri dönüş)
            level = graythresh(corrected);
            bw = imbinarize(corrected, level);
            
            % Polarite kontrolü (Zemin beyaz olmalı)
            if mean(bw(:)) < 0.5, bw = ~bw; end
            % Küçük gürültü temizleme
            bw = bwareaopen(bw, 15);
        end

    end
    methods (Access = public) % Test edilebilir olması için public yapıldı
        function detected = matchAllergens(obj, ocrResults)
            detected = struct('Word', {}, 'Category', {}, 'BBox', {}, 'Confidence', {});
            
            words = ocrResults.Words;
            boxes = ocrResults.WordBoundingBoxes;
            confs = ocrResults.WordConfidences;
            
            categories = fieldnames(obj.AllergenDB);
            
            for i = 1:length(words)
                ocrWordRaw = char(words{i});
                % OCR kelimesini temizle (sadece harf ve rakam, noktalama elenir)
                ocrWordClean = lower(ocrWordRaw);
                [~, ocrWordNorm] = fixTurkishCharacters(ocrWordClean);
                % Noktalama işaretlerini (.,;() vb.) tamamen temizleyelim
                ocrWordNorm = regexprep(ocrWordNorm, '[^a-z0-9]', '');
                
                if length(ocrWordNorm) < obj.Config.MinWordLength, continue; end
                
                matchFound = false;
                for c = 1:length(categories)
                    catName = categories{c};
                    catTerms = obj.AllergenDB.(catName);
                    
                    for t = 1:length(catTerms)
                        term = lower(char(catTerms{t}));
                        [~, termNorm] = fixTurkishCharacters(term);
                        termNorm = regexprep(termNorm, '[^a-z0-9]', ''); % Boşluk ve noktalama sil

                        % HASSAS EŞLEŞME MANTIĞI
                        % 1. Tam Eşleşme
                        if strcmp(ocrWordNorm, termNorm)
                            matchFound = true;
                        
                        % 2. Alt-string kontrolü (Örn: "sütlü" içindeki "süt")
                        elseif contains(ocrWordNorm, termNorm)
                            % Kural: Çok kısa kökler (örn: "et") kelime ortasındaysa elensin
                            % "bal" ve "süt" gibi 3 harfliler kelime başında olmalı
                            if length(termNorm) >= 4
                                matchFound = true;
                            elseif length(termNorm) == 3
                                if startsWith(ocrWordNorm, termNorm) && ~strcmp(ocrWordNorm, 'ambalaj')
                                    matchFound = true;
                                end
                            end
                        
                        % 3. Bulanık Eşleşme
                        elseif length(termNorm) > 4 && length(ocrWordNorm) > 4
                            dist = obj.levenshtein(ocrWordNorm, termNorm);
                            sim = 1 - (dist / max(length(ocrWordNorm), length(termNorm)));
                            if sim >= obj.Config.MinSimilarity
                                matchFound = true;
                            end
                        end

                        if matchFound
                            idx = length(detected) + 1;
                            detected(idx).Word = words{i};
                            detected(idx).Category = catName;
                            detected(idx).BBox = boxes(i, :);
                            detected(idx).Confidence = confs(i);
                            break;
                        end
                    end
                    if matchFound, break; end
                end
            end
            
            % TEKİLLEŞTİRME: Çakışan kutuları ve mükerrer tespitleri temizle
            if ~isempty(detected)
                % Benzer konumdaki aynı kategorideki kutuları birleştir (NMS benzeri)
                finalDetected = [];
                isSuppressed = false(1, length(detected));
                
                for i = 1:length(detected)
                    if isSuppressed(i), continue; end
                    
                    current = detected(i);
                    keep = true;
                    
                    for j = i+1:length(detected)
                        if isSuppressed(j), continue; end
                        
                        target = detected(j);
                        
                        % Aynı kategori mi?
                        if strcmp(current.Category, target.Category)
                            % Kutuların çakışma oranını (IOU) hesapla
                            box1 = current.BBox;
                            box2 = target.BBox;
                            
                            % Intersection area
                            x1 = max(box1(1), box2(1));
                            y1 = max(box1(2), box2(2));
                            x2 = min(box1(1)+box1(3), box2(1)+box2(3));
                            y2 = min(box1(2)+box1(4), box2(2)+box2(4));
                            
                            w = max(0, x2 - x1);
                            h = max(0, y2 - y1);
                            interArea = w * h;
                            
                            % Union area
                            unionArea = box1(3)*box1(4) + box2(3)*box2(4) - interArea;
                            iou = interArea / unionArea;
                            
                            % Eğer %50'den fazla çakışıyorsa, birini ele (yüksek confidence kalsın)
                            if iou > 0.5
                                if target.Confidence > current.Confidence
                                    keep = false;
                                    break;
                                else
                                    isSuppressed(j) = true;
                                end
                            end
                        end
                    end
                    
                    if keep
                        finalDetected = [finalDetected, current];
                    end
                end
                detected = finalDetected;
            end
        end

        function annotated = visualize(~, baseImg, ~, detected)
            % Dinamik Görselleştirme
            h = size(baseImg, 1);
            lw = max(2, round(h / 300));
            fs = max(10, round(h / 80));
            
            annotated = baseImg;
            if isempty(detected), return; end
            
            bboxes = reshape([detected.BBox], 4, [])';
            labels = {detected.Category};
            
            % Sadece kenarlık çiz (Opacity=0)
            annotated = insertShape(annotated, 'Rectangle', bboxes, ...
                'Color', 'red', 'LineWidth', lw, 'Opacity', 0);
            
            % Etiketleri ekle
            labelPos = bboxes(:, 1:2);
            labelPos(:,2) = max(lw+1, labelPos(:,2) - fs - 5);
            annotated = insertText(annotated, labelPos, labels, ...
                'FontSize', fs, 'BoxColor', 'red', 'BoxOpacity', 0.5, ...
                'TextColor', 'white', 'AnchorPoint', 'LeftBottom', 'Font', 'Arial Bold');
        end
        
        function d = levenshtein(~, s1, s2)
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
        end
    end
end
