% checkAllergens.m
% OCR ile okunan metinde kullanıcının seçtiği alerjenleri tarar
% Önceki adımdan gelen finalText değişkenini kullanır

%% 1) Workspace Kontrolü
if ~exist('finalText', 'var')
    error('finalText degiskeni bulunamadi! Once extractTextAdvanced.m calistirin.');
end

fprintf('\n========== ALERJEN TARAMA BASLADI ==========\n');
fprintf('Taranacak metin uzunlugu: %d karakter\n', length(finalText));

%% 2) Alerjen Veritabanını Yükle
try
    allergenDB = createAllergenDatabase();
    fprintf('Alerjen veritabani yuklendi.\n');
catch
    error('Alerjen veritabani yuklenemedi! createAllergenDatabase.m dosyasini kontrol edin.');
end

%% 3) Kullanıcı Alerji Seçimi (Simülasyon - İleride GUI'den gelecek)
% Not: Kategori isimleri allergenDB'deki field isimleriyle aynı olmalı
userAllergies = {'Sut', 'Gluten', 'Fistik', 'Findik', 'Yumurta'};

fprintf('Kullanici tarafindan secilen alerjiler:\n');
for i = 1:length(userAllergies)
    fprintf('  - %s\n', userAllergies{i});
end
fprintf('\n');

%% 4) Metni Normalize Et (Arama için hazırla)
searchText = lower(finalText);
searchText = strrep(searchText, 'ı', 'i');
searchText = strrep(searchText, 'ğ', 'g');
searchText = strrep(searchText, 'ü', 'u');
searchText = strrep(searchText, 'ş', 's');
searchText = strrep(searchText, 'ö', 'o');
searchText = strrep(searchText, 'ç', 'c');

% Noktalama işaretlerini kaldır (parantez, nokta, virgül vs.)
searchText = regexprep(searchText, '[^a-z0-9\sşğüöçı]', ' ');

%% 5) Arama Algoritması (Fuzzy Matching ile)
detectedAllergens = struct();
isSafe = true;

% Debug: Yakın eşleşmeleri kaydet
nearMisses = {};

fprintf('\n--- ALERJEN ARAMA (FUZZY MATCHING AKTIF) ---\n');

for i = 1:length(userAllergies)
    categoryName = userAllergies{i};
    
    if ~isfield(allergenDB, categoryName)
        warning('Kategori bulunamadi: %s (Atlaniyor)', categoryName);
        continue;
    end
    
    allergenTerms = allergenDB.(categoryName);
    foundTerms = {};
    
    % Her terimi metinde ara
    for j = 1:length(allergenTerms)
        term = char(allergenTerms{j});
        termNorm = lower(term);
        termNorm = strrep(termNorm, 'ı', 'i');
        termNorm = strrep(termNorm, 'ğ', 'g');
        termNorm = strrep(termNorm, 'ü', 'u');
        termNorm = strrep(termNorm, 'ş', 's');
        termNorm = strrep(termNorm, 'ö', 'o');
        termNorm = strrep(termNorm, 'ç', 'c');
        
        % 1) Tam kelime eşleşmesi (word boundary kontrolü)
        % Sadece 4+ karakterli alerjen terimleri için
        if length(termNorm) >= 4
            % Çok kelimeli alerjen mi kontrol et (ör: "turk findigi", "sut tozu")
            termWords = strsplit(termNorm);
            ocrWords = strsplit(searchText);
            
            if length(termWords) == 1
                % TEK KELİME alerjen: OCR kelimeleri arasında TAM EŞLEŞME ara
                % "yag" != "tereyagi", "turk" != "turk findigi"
                for wordIdx = 1:length(ocrWords)
                    ocrWord = char(ocrWords{wordIdx});
                    if strcmp(ocrWord, termNorm)
                        foundTerms{end+1} = term;
                        isSafe = false;
                        fprintf('  [TAM ESLESME] "%s" == "%s"\n', ocrWord, term);
                        break;
                    end
                end
            else
                % ÇOK KELİMELİ alerjen: Ardışık kelime dizisi ara
                % "turk findigi" için "turk" ve "findigi" yan yana olmalı
                % Ek koruma: Alerjen kelimelerinin tümü 3+ karakter olmalı
                allWordsValid = true;
                for tIdx = 1:length(termWords)
                    if length(char(termWords{tIdx})) < 3
                        allWordsValid = false;
                        break;
                    end
                end
                
                if ~allWordsValid
                    continue;
                end
                
                for wordIdx = 1:(length(ocrWords) - length(termWords) + 1)
                    match = true;
                    for termIdx = 1:length(termWords)
                        if ~strcmp(ocrWords{wordIdx + termIdx - 1}, termWords{termIdx})
                            match = false;
                            break;
                        end
                    end
                    if match
                        foundTerms{end+1} = term;
                        isSafe = false;
                        fprintf('  [COK KELIME ESLESME] "%s" bulundu\n', term);
                        break;
                    end
                end
            end
            
            if ~isempty(foundTerms) && strcmp(foundTerms{end}, term)
                continue;
            end
        end
        
        % 2) Fuzzy matching (Levenshtein Distance)
        % SADECE TEK KELİMELİ alerjenler için fuzzy matching yap
        % Çok kelimeli alerjenlerde ("türk fındığı") fuzzy matching yapma
        termWords = strsplit(termNorm);
        if length(termWords) > 1
            % Çok kelimeli alerjen - fuzzy matching atla
            continue;
        end
        
        % Metindeki kelimeleri ayır ve teker teker kontrol et
        words = strsplit(searchText);
        for k = 1:length(words)
            word = char(words{k});
            
            % Noktalama kaldır (eğer kaldıysa)
            word = regexprep(word, '[^a-z0-9şğüöçı]', '');
            
            % Sadece 4+ harfli kelimeleri kontrol et (çok kısa kelimeler alerjen olamaz)
            if length(word) < 4 || length(termNorm) < 4
                continue;
            end
            
            % Levenshtein distance hesapla
            dist = levenshteinDistance(word, termNorm);
            maxLen = max(length(word), length(termNorm));
            similarity = 1 - (dist / maxLen);
            
            % %75 ve üstü benzerlik varsa kabul et
            if similarity >= 0.75
                if similarity >= 0.85
                    % Yüksek benzerlik - kabul et
                    foundTerms{end+1} = term;
                    isSafe = false;
                    fprintf('  [FUZZY-HIGH] "%s" ~ "%s" (benzerlik: %.1f%%)\n', word, term, similarity*100);
                    break;
                else
                    % Orta benzerlik - debug için kaydet
                    nearMisses{end+1} = sprintf('%s ~ %s (%.1f%%)', word, term, similarity*100);
                    fprintf('  [FUZZY-CLOSE] "%s" ~ "%s" (benzerlik: %.1f%% - yakin ama yeterli degil)\n', word, term, similarity*100);
                end
            end
        end
    end
    
    % Eğer bu kategoride terim bulunduysa kaydet
    if ~isempty(foundTerms)
        detectedAllergens.(categoryName) = foundTerms;
    end
end

%% 6) Raporlama
fprintf('\n========================================\n');
fprintf('===   ALERJEN TARAMA RAPORU          ===\n');
fprintf('========================================\n\n');

if isSafe
    % Hiçbir alerjen bulunamadı
    fprintf('✓ GUVENLI: Sectiginiz alerjenlere rastlanmadi.\n');
    fprintf('Bu urun sizin icin uygun gorunuyor.\n');
    detectedList = [];
else
    % Alerjen(ler) bulundu
    fprintf('!!! TEHLIKE: Alerjen tespit edildi!\n\n');
    
    detectedCategories = fieldnames(detectedAllergens);
    detectedList = {};
    
    for i = 1:length(detectedCategories)
        categoryName = detectedCategories{i};
        foundTerms = detectedAllergens.(categoryName);
        
        fprintf('  >> KATEGORI: %s\n', categoryName);
        fprintf('     Bulunan terimler (%d adet):\n', length(foundTerms));
        
        for j = 1:length(foundTerms)
            fprintf('       - %s\n', foundTerms{j});
            detectedList{end+1} = sprintf('%s: %s', categoryName, foundTerms{j});
        end
        fprintf('\n');
    end
    
    fprintf('!!! UYARI: Bu urunu TUKETMEYIN!\n');
end

fprintf('\n========================================\n\n');

%% Debug: Yakın eşleşmeleri göster
if ~isempty(nearMisses)
    fprintf('--- DEBUG: YAKIN ESLESMELER (%%75-85 benzerlik) ---\n');
    for i = 1:min(10, length(nearMisses))
        fprintf('  %s\n', nearMisses{i});
    end
    if length(nearMisses) > 10
        fprintf('  ... ve %d yakin eslesme daha\n', length(nearMisses) - 10);
    end
    fprintf('\n');
end

%% 7) Sonuçları Workspace'e Aktar
assignin('base', 'isSafe', isSafe);
assignin('base', 'detectedAllergens', detectedAllergens);
if ~isempty(detectedList)
    assignin('base', 'detectedList', detectedList);
end

fprintf('>>> Sonuc degiskenleri workspace''e aktarildi:\n');
fprintf('    - isSafe (boolean): %s\n', mat2str(isSafe));
if ~isSafe
    fprintf('    - detectedAllergens (struct): Kategorilere gore bulunan terimler\n');
    fprintf('    - detectedList (cell array): Tum bulunan terimler listesi\n');
end

fprintf('\n========== ALERJEN TARAMA TAMAMLANDI ==========\n\n');

%% 8) İstatistikler
fprintf('--- ISTATISTIKLER ---\n');
fprintf('Taranan kategori sayisi: %d\n', length(userAllergies));
fprintf('Metinde aranan toplam terim sayisi: ');

totalSearched = 0;
for i = 1:length(userAllergies)
    if isfield(allergenDB, userAllergies{i})
        totalSearched = totalSearched + length(allergenDB.(userAllergies{i}));
    end
end
fprintf('%d\n', totalSearched);

if ~isSafe
    fprintf('Tespit edilen alerjen kategorisi: %d\n', length(fieldnames(detectedAllergens)));
    fprintf('Bulunan toplam terim sayisi: %d\n', length(detectedList));
end

fprintf('\n');

%% YARDIMCI FONKSIYON: Levenshtein Distance
function distance = levenshteinDistance(str1, str2)
% İki string arasındaki Levenshtein (edit) distance hesaplar
% Düşük distance = yüksek benzerlik
    
    m = length(str1);
    n = length(str2);
    
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
