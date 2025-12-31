function [fixedText, normalizedText] = fixTurkishCharacters(inputText)
% fixTurkishCharacters - OCR çıktısındaki Türkçe karakter hatalarını düzeltir
%
% KULLANIM:
%   [fixedText, normalizedText] = fixTurkishCharacters(inputText)
%
% GİRİŞ:
%   inputText - OCR'dan gelen ham metin (string veya char)
%
% ÇIKIŞ:
%   fixedText       - Türkçe karakterler düzeltilmiş metin
%   normalizedText  - Türkçe karaktersiz (normalize) versiyon (alerjen eşleştirme için)
%
% ÖRNEK:
%   text = 'buðday, þeker, yumurta';
%   [fixed, norm] = fixTurkishCharacters(text);
%   % fixed = 'buğday, şeker, yumurta'
%   % norm  = 'bugday, seker, yumurta'

    % Giriş kontrolü
    if isempty(inputText)
        fixedText = '';
        normalizedText = '';
        return;
    end
    
    % String'i char'a çevir
    workingText = char(inputText);
    
    %% 1) OCR KARAKTER HATALARI DÜZELTMESİ
    % OCR'ın Türkçe karakterleri yanlış okuması için yaygın düzeltmeler
    
    % Ş harfi düzeltmeleri
    workingText = strrep(workingText, 'þ', 'ş');  % þ -> ş
    workingText = strrep(workingText, 'Þ', 'Ş');  % Þ -> Ş
    workingText = strrep(workingText, '$', 'ş');   % $ -> ş (bazı OCR'larda)
    
    % Ğ harfi düzeltmeleri
    workingText = strrep(workingText, 'ð', 'ğ');  % ð -> ğ
    workingText = strrep(workingText, 'Ð', 'Ğ');  % Ð -> Ğ
    workingText = strrep(workingText, 'g˘', 'ğ'); % g˘ -> ğ
    
    % İ/I harfi düzeltmeleri
    workingText = strrep(workingText, 'ý', 'ı');  % ý -> ı
    workingText = strrep(workingText, 'Ý', 'İ');  % Ý -> İ
    workingText = strrep(workingText, 'i̇', 'i');  % Noktalı i düzeltmesi
    workingText = strrep(workingText, 'I', 'ı');  % Büyük I -> küçük ı (Türkçe kuralı için güvenli)
    workingText = strrep(workingText, 'İ', 'i');  % Büyük İ -> küçük i
    
    % Ü harfi düzeltmeleri
    workingText = strrep(workingText, 'ü', 'ü');  % ü -> ü (farklı encoding)
    workingText = strrep(workingText, 'Ü', 'Ü');  % Ü -> Ü
    
    % Ö harfi düzeltmeleri
    workingText = strrep(workingText, 'ö', 'ö');  % ö -> ö (farklı encoding)
    workingText = strrep(workingText, 'Ö', 'Ö');  % Ö -> Ö
    
    % Ç harfi düzeltmeleri
    workingText = strrep(workingText, 'ç', 'ç');  % ç -> ç (farklı encoding)
    workingText = strrep(workingText, 'Ç', 'Ç');  % Ç -> Ç
    workingText = strrep(workingText, 'c¸', 'ç'); % c¸ -> ç
    
    % OCR'ın bazen karıştırdığı diğer harfler
    workingText = strrep(workingText, '0', 'o');  % 'sut' yerine 's0t' okuma durumu için riskli ama alerjende yaygın
    
    % Regex ile diğer garip karakterleri temizle (Harf, rakam ve standart noktalama kalsın)
    workingText = regexprep(workingText, '[^\w\sçÇğĞıİöÖşŞüÜ.,;:()\%\-\/]', '');
    
    fixedText = workingText;
    
    %% 2) NORMALIZASYON (Türkçe Karaktersiz Hale Getir)
    % Alerjen veritabanı ile eşleştirme için önemli
    normalizedText = fixedText;
    
    % Türkçe karakterleri yakın İngilizce harflerle değiştir
    normalizedText = strrep(normalizedText, 'ç', 'c');
    normalizedText = strrep(normalizedText, 'Ç', 'C');
    normalizedText = strrep(normalizedText, 'ğ', 'g');
    normalizedText = strrep(normalizedText, 'Ğ', 'G');
    normalizedText = strrep(normalizedText, 'ı', 'i');
    normalizedText = strrep(normalizedText, 'İ', 'I');
    normalizedText = strrep(normalizedText, 'ö', 'o');
    normalizedText = strrep(normalizedText, 'Ö', 'O');
    normalizedText = strrep(normalizedText, 'ş', 's');
    normalizedText = strrep(normalizedText, 'Ş', 'S');
    normalizedText = strrep(normalizedText, 'ü', 'u');
    normalizedText = strrep(normalizedText, 'Ü', 'U');
    
    % Küçük harfe çevir
    normalizedText = lower(normalizedText);
    
    % Çoklu boşlukları tek boşluğa indir
    normalizedText = regexprep(normalizedText, '\s+', ' ');
    normalizedText = strtrim(normalizedText);
    
    %% 3) GÖRSEL KONTROL
    % fprintf('--- Turkce Karakter Duzeltme Raporu ---\n');
    % fprintf('Orjinal uzunluk: %d karakter\n', length(inputStr));
    % fprintf('Duzeltilmis uzunluk: %d karakter\n', length(correctedStr));
    % fprintf('Normalize uzunluk: %d karakter\n', length(normalizedStr));
    
    if ~strcmp(inputText, fixedText)
        % fprintf('>> Karakter duzeltmeleri yapildi.\n');
    else
         % fprintf('>> Duzeltme yapildi: %s -> %s\n', inputStr, correctedStr); bulunamadi.\n');
    end
    
end


%% YARDIMCI FONKSIYON: Levenstein Distance
function distance = levenshteinDistance(str1, str2)
% İki string arasındaki Levenstein (edit) distance hesaplar
% Düşük distance = yüksek benzerlik
    
    m = length(str1);
    n = length(str2);
    
    % Boş string kontrolü
    if m == 0
        distance = n;
        return;
    end
    if n == 0
        distance = m;
        return;
    end
    
    % DP matrisi oluştur
    dp = zeros(m + 1, n + 1);
    
    % İlk satır ve sütunu başlat
    for i = 0:m
        dp(i + 1, 1) = i;
    end
    for j = 0:n
        dp(1, j + 1) = j;
    end
    
    % DP ile distance hesapla
    for i = 1:m
        for j = 1:n
            if str1(i) == str2(j)
                cost = 0;
            else
                cost = 1;
            end
            
            dp(i + 1, j + 1) = min([...
                dp(i, j + 1) + 1, ...      % Silme
                dp(i + 1, j) + 1, ...      % Ekleme
                dp(i, j) + cost]);         % Değiştirme
        end
    end
    
    distance = dp(m + 1, n + 1);
end


%% YARDIMCI FONKSIYON: Benzerlik Kontrolü
function isSimilar = checkSimilarity(word1, word2, threshold)
% İki kelime arasındaki benzerliği kontrol eder
%
% threshold: 0-1 arası benzerlik eşiği (örn: 0.8 = %80 benzerlik)

    if nargin < 3
        threshold = 0.8; % Varsayılan %80 benzerlik
    end
    
    % Aynıysa direkt true
    if strcmp(word1, word2)
        isSimilar = true;
        return;
    end
    
    % Levenstein distance hesapla
    dist = levenshteinDistance(word1, word2);
    maxLen = max(length(word1), length(word2));
    
    % Benzerlik oranı hesapla
    similarity = 1 - (dist / maxLen);
    
    isSimilar = similarity >= threshold;
end
