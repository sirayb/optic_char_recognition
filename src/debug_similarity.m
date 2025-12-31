%% debug_similarity.m
imagePath = 'C:/Users/Golieth/.gemini/antigravity/brain/2bccbba7-9ba4-442d-9237-fee735f53403/uploaded_image_1767125912345.jpg';
detector = AllergenDetector();

% Run Process
[~, ~, ocrResults] = detector.processImage(imagePath);

targets = {'sut', 'yumurta', 'soya', 'fistik'};
fid = fopen('similarity_clean.txt', 'w', 'n', 'UTF-8');
fprintf(fid, '--- DETAYLI BENZERLIK ANALIZI ---\n');

if isempty(ocrResults.Words)
    fprintf(fid, 'HIC KELIME BULUNAMADI!\n');
    fclose(fid);
    return;
end

for t = 1:length(targets)
    target = targets{t};
    fprintf(fid, '\nHEDEF: "%s" (Min Len: 3, Threshold: 0.65)\n', target);
    fprintf(fid, '%-20s %-10s %-10s %-10s\n', 'OCR Word', 'Conf', 'Dist', 'Sim');
    fprintf(fid, '----------------------------------------------------\n');
    
    matches_found = 0;
    
    % Store all for sorting
    data = [];
    
    for i = 1:length(ocrResults.Words)
        word = ocrResults.Words{i};
        % Normalize
        wNorm = lower(word);
        wNorm = regexprep(wNorm, '[^a-z0-9]', '');
        
        if length(wNorm) < 2, continue; end
        
        dist = levenshteinDistance(wNorm, target);
        maxLen = max(length(wNorm), length(target));
        sim = 1 - (dist / maxLen);
        
        data = [data; struct('word', word, 'conf', ocrResults.WordConfidences(i), 'dist', dist, 'sim', sim)];
    end
    
    % Sort by Similarity Descending
    [~, idx] = sort([data.sim], 'descend');
    sortedData = data(idx);
    
    % Print Top 10 Closest
    for k = 1:min(length(sortedData), 10)
        d = sortedData(k);
        matchMark = '';
        if d.sim >= 0.65, matchMark = '<- MATCH!'; end
        fprintf(fid, '%-20s %-10.2f %-10d %-10.2f %s\n', d.word, d.conf, d.dist, d.sim, matchMark);
    end
end
fclose(fid);

%% Helper
function distance = levenshteinDistance(str1, str2)
    m = length(str1); n = length(str2);
    if m == 0, distance = n; return; end
    if n == 0, distance = m; return; end
    dp = zeros(m + 1, n + 1);
    for i = 0:m, dp(i + 1, 1) = i; end
    for j = 0:n, dp(1, j + 1) = j; end
    for i = 1:m
        for j = 1:n
            cost = (str1(i) ~= str2(j));
            dp(i + 1, j + 1) = min([dp(i, j + 1) + 1, dp(i + 1, j) + 1, dp(i, j) + cost]);
        end
    end
    distance = dp(m + 1, n + 1);
end
