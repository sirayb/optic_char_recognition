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

    if nargin < 2
        scaledImg = processedImg; % Eğer scaledImg verilmediyse processedImg kullan
    end

    fprintf('\n--- GELISMIS MULTI-SCALE OCR BASLADI ---\n');

    % Metin Onarma (Morfologik Closing - Karakterleri birleştirmek için)
    % Zemin beyaz olduğu için (1), işlemi ters çevirip (0=metin -> 1=metin) yapıyoruz.
    se = strel('disk', 1);
    processedImg = ~imclose(~processedImg, se);
    fprintf('  Metin onarma (closing) uygulandı.\n');

    % Tanımlanan ölçekler (Genişletildi): 
    % 0.25x: Devasa başlıklar için (Yeni eklendi)
    % 0.5x: Büyük başlıklar için
    % 1.0x: Normal boyutlu yazılar için
    % 2.0x: Çok küçük detay yazıları için
    scales = [0.25, 0.5, 1.0, 2.0];
    
    allWords = {};
    allBoxes = [];
    allConfidences = [];
    
    currentImgHeight = size(processedImg, 1);

    for s = scales
        fprintf('  Olcek %.1f taranıyor... ', s);
        
        % Görüntüyü ölçekle
        if s == 1.0
            workImg = processedImg;
        else
            workImg = imresize(processedImg, s, 'bicubic');
        end
        
        % OCR Çalıştır (Önce Türkçe dene, olmazsa varsayılan)
        try
            try
                results = ocr(workImg, 'Language', 'turkish', 'TextLayout', 'Word');
            catch
                try
                    results = ocr(workImg, 'TextLayout', 'Word');
                catch
                    results = ocr(workImg);
                end
            end
            
            words = results.Words;
            boxes = results.WordBoundingBoxes;
            confs = results.WordConfidences;
                
            if ~isempty(words)
                % Koordinatları orijinal (processedImg) boyutuna geri dönüştür
                % Formül: OrijinalBox = CizilenBox / s
                correctedBoxes = boxes / s;
                
                allWords = [allWords; words];
                allBoxes = [allBoxes; correctedBoxes];
                allConfidences = [allConfidences; confs];
                
                fprintf('%d kelime bulundu.\n', length(words));
            else
                fprintf('kelime bulunamadı.\n');
            end
        catch ME
            fprintf('HATA: %.1f olcegi islenemedi (%s).\n', s, ME.message);
        end
    end

    % OCR sonuçlarını struct olarak birleştir
    ocrResults = struct();
    ocrResults.Words = allWords;
    ocrResults.WordBoundingBoxes = allBoxes;
    ocrResults.WordConfidences = allConfidences;
    
    % Metni tek bir string olarak birleştir (başarı istatistikleri için)
    ocrResults.Text = strjoin(allWords, ' ');

    fprintf('--- OCR ISI BITTI: Toplam %d kelime yakalandı ---\n\n', length(allWords));

end
