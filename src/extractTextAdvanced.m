function [ocrResults, allWords, allBoxes] = extractTextAdvanced(processedImg, scaledImg)
% extractTextAdvanced - Gelişmiş Çoklu Ölçekli (Multi-scale) OCR İşlemi
% Farklı boyutlardaki yazıları (başlıklar ve küçük yazılar) yakalamak için tasarlanmıştır.

    % Argüman kontrolü ve script-modu uyumluluğu
    if nargin < 1
        try
            % Eğer parametre verilmediyse workspace'deki processedImg'i kullanmayı dene
            processedImg = evalin('base', 'processedImg');
            fprintf('Bilgi: processedImg workspace''ten çekildi.\n');
        catch
            error('HATA: Giriş resmi (processedImg) eksik! Lütfen fonksiyonu bir değişkenle çağırın veya preprocessImage çalıştırın.');
        end
    end

    % Görüntü hazırlığı
    % processedImg zaten binary (logical) gelmeli.
    % Ekstra binarization YAPMA (Görüntüyü bozuyor).
    binaryImg = processedImg;

    % Metin onarma (Morfologik Closing)
    % Orijinal disk 1 yapısına dönüş.
    se = strel('disk', 1); 
    binaryImg = ~imclose(~binaryImg, se);
    % fprintf('  Metin onarma (closing) uygulandı.\n');
    
    ocrResults = struct('Words', {{}}, 'WordBoundingBoxes', [], 'WordConfidences', []);
    allWords = {};
    allBoxes = [];
    allConfs = [];
    
    % Multi-scale (Çoklu Ölçek) Tarama
    scales = [0.5, 1.0, 2.0, 3.0]; % 0.2'yi kaldırdık (çok yavaş/gereksiz olabilir), 3.0 kritik küçükler için
    
    currentImgHeight = size(processedImg, 1);

    for s_idx = 1:length(scales)
        sc = scales(s_idx);
        % fprintf('  Olcek %.1f taranıyor... ', sc);
        
        % Görüntüyü ölçekle
        if sc == 1.0
            workImg = binaryImg; % Use binaryImg for OCR
        else
            workImg = imresize(binaryImg, sc, 'bicubic'); % Use binaryImg for OCR
        end
        
        % OCR Çalıştır (Önce Türkçe dene, olmazsa varsayılan)
        try
            try
                res = ocr(workImg, 'Language', 'turkish');
            catch
                res = ocr(workImg);
            end
            
           % Sonuçları biriktir
        if ~isempty(res.Words)
            countBefore = length(allWords);
            for k = 1:length(res.Words)
                w = res.Words{k};
                % Boş veya çok kısa (tek harf) gürültüleri filtrele
                if isempty(w) || length(w) < 2, continue; end
                
                % Confidence filtresini KALDIRDIK (Süt 0.00 gelebiliyor)
                % if res.WordConfidences(k) < 0.4, continue; end 
                
                % Koordinatları ölçeğe göre geri dönüştür
                rawBox = res.WordBoundingBoxes(k, :);
                realBox = rawBox / sc;
                
                allWords{end+1} = w;
                allBoxes = [allBoxes; realBox];
                allConfs = [allConfs; res.WordConfidences(k)];
            end
            countAfter = length(allWords);
            % fprintf('%d kelime bulundu.\n', countAfter - countBefore);
        else
            % fprintf('kelime bulunamadı.\n');
        end
        catch ME
            fprintf('HATA: %.1f olcegi islenemedi (%s).\n', s, ME.message);
        end
    end
    
    % Sonuçları döndür
    words = allWords;
    boxes = allBoxes;
    confidences = allConfs;

    % OCR sonuçlarını struct olarak birleştir
    ocrResults = struct();
    ocrResults.Words = allWords;
    ocrResults.WordBoundingBoxes = allBoxes;
    ocrResults.WordConfidences = allConfs;
    
    % Metni tek bir string olarak birleştir (başarı istatistikleri için)
    ocrResults.Text = strjoin(allWords, ' ');

    fprintf('--- OCR ISI BITTI: Toplam %d kelime yakalandı ---\n\n', length(allWords));

end
