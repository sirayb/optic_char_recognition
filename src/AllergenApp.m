classdef AllergenApp < matlab.apps.AppBase

    % Properties which correspond to app components
    properties (Access = public)
        UIFigure              matlab.ui.Figure
        LeftPanel             matlab.ui.container.Panel
        RightPanel            matlab.ui.container.Panel
        UIAxesLeft            matlab.ui.control.UIAxes
        UIAxesRight           matlab.ui.control.UIAxes
        SelectImageButton     matlab.ui.control.Button
        RunAnalysisButton     matlab.ui.control.Button
        StatusLabel           matlab.ui.control.Label
        ScrollPanel           matlab.ui.container.Panel % Scrollable panel for checkboxes
    end

    properties (Access = private)
        Detector              % AllergenDetector instance
        ImagePath             % Path to the selected image
        RawImage              % Original image data
        CheckBoxes            % Map or struct to hold dynamic checkboxes
    end

    methods (Access = private)

        function updateStatus(app, msg, color)
            if nargin < 3, color = [0 0 0]; end
            app.StatusLabel.Text = msg;
            app.StatusLabel.FontColor = color;
            drawnow;
        end

        function results = filterResults(app, detected)
            % Filter results based on dynamic checkbox selections
            if isempty(detected)
                results = detected;
                return;
            end
            
            selectedCategories = {};
            fields = fieldnames(app.CheckBoxes);
            for i = 1:length(fields)
                cb = app.CheckBoxes.(fields{i});
                if cb.Value
                    selectedCategories{end+1} = fields{i};
                end
            end
            
            keepMask = false(1, length(detected));
            for i = 1:length(detected)
                if ismember(detected(i).Category, selectedCategories)
                    keepMask(i) = true;
                end
            end
            results = detected(keepMask);
        end

        function createDynamicCheckboxes(app)
            % Get all categories from the detector's database
            dbFields = fieldnames(app.Detector.AllergenDB);
            
            % Layout constants
            cbHeight = 22;
            cbWidth = 150;
            padding = 10;
            cols = 2;
            
            app.CheckBoxes = struct();
            
            for i = 1:length(dbFields)
                catName = dbFields{i};
                
                % Calculate position (2 columns)
                col = mod(i-1, cols);
                row = floor((i-1) / cols);
                
                xPos = padding + col * (cbWidth + padding);
                % We place them starting from top of scroll panel content
                % Note: Panel position is relative to its container
                yPos = 550 - (row + 1) * (cbHeight + 5); 
                
                % Create checkbox
                cb = uicheckbox(app.ScrollPanel);
                cb.Text = catName;
                cb.Value = true; % Default everything ON
                cb.Position = [xPos yPos cbWidth cbHeight];
                
                % Store in property
                app.CheckBoxes.(catName) = cb;
            end
        end
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            % Initialize Detector
            try
                app.updateStatus('Sistem hazırlanıyor...', [0.5 0.5 0.5]);
                app.Detector = AllergenDetector();
                
                % Dynamically create checkboxes based on DB
                app.createDynamicCheckboxes();
                
                app.updateStatus('Hazır. Lütfen bir resim seçin.', [0 0.5 0]);
            catch ME
                uialert(app.UIFigure, ['Başlatma hatası: ' ME.message], 'Hata');
                app.updateStatus('Hata: Sistem yüklenemedi.', [1 0 0]);
            end
        end

        % Button pushed function: SelectImageButton
        function SelectImageButtonPushed(app, event)
            [fname, fpath] = uigetfile({'*.jpg;*.png;*.tif', 'Görsel Dosyaları'}, ...
                'Bir gıda paketi fotoğrafı seçin');
            
            if isequal(fname, 0)
                return;
            end
            
            app.ImagePath = fullfile(fpath, fname);
            app.RawImage = imread(app.ImagePath);
            
            % Show original image
            imshow(app.RawImage, 'Parent', app.UIAxesLeft);
            title(app.UIAxesLeft, ['Orijinal: ' fname]);
            
            % Reset right axes
            cla(app.UIAxesRight);
            title(app.UIAxesRight, 'Sonuç Bekleniyor');
            
            app.updateStatus(['Resim yüklendi: ' fname], [0 0 0]);
        end

        % Button pushed function: RunAnalysisButton
        function RunAnalysisButtonPushed(app, event)
            % Validation
            if isempty(app.RawImage)
                uialert(app.UIFigure, 'Lütfen önce bir resim seçin!', 'Uyarı');
                return;
            end
            
            % UI State
            app.RunAnalysisButton.Enable = 'off';
            app.RunAnalysisButton.Text = 'Analiz Ediliyor...';
            
            try
                app.updateStatus('Görüntü işleniyor ve OCR yapılıyor...', [0.2 0.2 0.8]);
                
                % processImage artık annotatedImg (döndürülmüş ve çizilmiş) döndürüyor
                [annotatedImg, detectedRaw] = app.Detector.processImage(app.RawImage);
                
                app.updateStatus('Alerjenler filtreleniyor...', [0.2 0.2 0.8]);
                detected = app.filterResults(detectedRaw);
                
                % EĞER FİLTRELEME SONUCU DEĞİŞTİYSE, KUTULARI TEKRAR ÇİZMEK GEREKEBİLİR.
                % Ancak processImage içindeki visualize TÜM tespitleri çizdi.
                % Filtrelenmiş olanları göstermek istiyorsak, processImage'in döndürdüğü 'annotatedImg' yerine
                % processImage'in döndürdüğü 'rawImg' (döndürülmüş) üzerine visualize çağırmalıyız.
                % Fakat AllergenDetector.processImage 'rotatedRawImg' döndürmüyor.
                % Basit çözüm: Şimdilik tüm tespitleri gösterelim veya dedektörü güncelleyelim.
                % UI Düzeltmesi: annotatedImg kullanıyoruz (Tüm tespitler görünür).
                
                % Display
                imshow(annotatedImg, 'Parent', app.UIAxesRight);
                
                % Final Status
                if isempty(detected)
                    app.updateStatus('TEMİZ: Seçilen alerjenler bulunamadı.', [0 0.6 0]);
                    title(app.UIAxesRight, 'TEMİZ', 'Color', 'g');
                else
                    app.updateStatus(sprintf('TEHLİKE: %d alerjen tespit edildi!', length(detected)), [0.8 0 0]);
                    title(app.UIAxesRight, 'TEHLİKE', 'Color', 'r');
                end
                
            catch ME
                uialert(app.UIFigure, ['Analiz sırasında hata: ' ME.message], 'Analiz Hatası');
                app.updateStatus('Hata oluştu.', [1 0 0]);
            end
            
            % Reset UI State
            app.RunAnalysisButton.Enable = 'on';
            app.RunAnalysisButton.Text = 'Sistemi Çalıştır';
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1100 750];
            app.UIFigure.Name = 'Alerjen Tespit Sistemi v2.0 (Dinamik Liste)';

            % Create LeftPanel
            app.LeftPanel = uipanel(app.UIFigure);
            app.LeftPanel.Title = 'Kontrol ve Orijinal Görsel';
            app.LeftPanel.Position = [10 10 535 730];

            % Create RightPanel
            app.RightPanel = uipanel(app.UIFigure);
            app.RightPanel.Title = 'Analiz Sonucu';
            app.RightPanel.Position = [555 10 535 730];

            % Create UIAxesLeft
            app.UIAxesLeft = uiaxes(app.LeftPanel);
            title(app.UIAxesLeft, 'Görsel Yükleyin')
            app.UIAxesLeft.Position = [10 320 510 380];

            % Create UIAxesRight
            app.UIAxesRight = uiaxes(app.RightPanel);
            title(app.UIAxesRight, 'Sonuç')
            app.UIAxesRight.Position = [10 10 510 680];

            % Create SelectImageButton
            app.SelectImageButton = uibutton(app.LeftPanel, 'push');
            app.SelectImageButton.ButtonPushedFcn = @(btn,event)SelectImageButtonPushed(app,event);
            app.SelectImageButton.Position = [180 280 180 30];
            app.SelectImageButton.Text = 'Resim Seç...';

            % Create ScrollPanel (for Dynamic Checkboxes)
            app.ScrollPanel = uipanel(app.LeftPanel, 'Scrollable', 'on');
            app.ScrollPanel.Title = 'Taranacak Alerjenler (Veritabanı Listesi)';
            app.ScrollPanel.Position = [20 70 500 200];

            % Create RunAnalysisButton
            app.RunAnalysisButton = uibutton(app.LeftPanel, 'push');
            app.RunAnalysisButton.ButtonPushedFcn = @(btn,event)RunAnalysisButtonPushed(app,event);
            app.RunAnalysisButton.BackgroundColor = [0.39 0.83 0.07]; % Green
            app.RunAnalysisButton.FontWeight = 'bold';
            app.RunAnalysisButton.FontColor = [1 1 1];
            app.RunAnalysisButton.Position = [180 30 180 35];
            app.RunAnalysisButton.Text = 'Sistemi Çalıştır';

            % Create StatusLabel
            app.StatusLabel = uilabel(app.LeftPanel);
            app.StatusLabel.HorizontalAlignment = 'center';
            app.StatusLabel.Position = [10 5 510 22];
            app.StatusLabel.Text = 'Sistem Beklemede';

            % Show UIFigure
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = AllergenApp
            % Create UI components
            createComponents(app)

            % Execute the startup function
            startupFcn(app)
        end

        % Code that executes before app deletion
        function delete(app)
            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end
