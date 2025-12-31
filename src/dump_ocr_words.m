
% dump_ocr_words.m
imagePath = 'C:/Users/Golieth/.gemini/antigravity/brain/2bccbba7-9ba4-442d-9237-fee735f53403/uploaded_image_1767125912345.jpg';
detector = AllergenDetector();

[~, ~, ocrResults] = detector.processImage(imagePath);

fid = fopen('ocr_dump.txt', 'w', 'n', 'UTF-8');
if isfield(ocrResults, 'Words')
    words = ocrResults.Words;
    confs = ocrResults.WordConfidences;
    for k = 1:length(words)
        fprintf(fid, '%d: %s (Conf: %.2f)\n', k, words{k}, confs(k));
    end
end
fclose(fid);
fprintf('OCR kelime listesi ocr_dump.txt dosyasina yazildi.\n');
