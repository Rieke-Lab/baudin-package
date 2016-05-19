classdef IsomerizationsConverterJacob < symphonyui.ui.Module

    properties
        leds
        ledListeners
        species
        photoreceptors
        orderedPhotoreceptorKeys
    end

    properties
        ledPopupMenu
        ndfsField
        gainField
        speciesField
        photoreceptorPopupMenu

        voltsBox
        photoreceptorBoxes
    end

    methods

        function createUi(obj, figureHandle)
            import appbox.*;
            import symphonyui.app.App;

            
            % start by getting some information about the photoreceptors
            % because it will determine the number of rows in the window,
            % and therefore the window's size
            obj.species = obj.findSpecies();
            obj.photoreceptors = obj.findPhotoreceptors();
            obj.orderedPhotoreceptorKeys = obj.orderPhotoreceptorKeys();
            
            
            set(figureHandle, ...
                'Name', 'Isomerizations Converter', ...
                'Position', screenCenter(270, 304));

            mainLayout = uix.VBox( ...
                'Parent', figureHandle);
            
            setupBox = uix.BoxPanel( ...
                'Parent', mainLayout, ...
                'Title', 'Light', ...
                'BorderType', 'none', ...
                'FontName', get(figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(figureHandle, 'DefaultUicontrolFontSize'), ...
                'Padding', 11);
            setupLayout = uix.Grid( ...
                'Parent', setupBox, ...
                'Spacing', 7);
            Label( ...
                'Parent', setupLayout, ...
                'String', 'LED:');
            Label( ...
                'Parent', setupLayout, ...
                'String', 'NDFs:');
            Label( ...
                'Parent', setupLayout, ...
                'String', 'Gain:');  
            Label( ...
                'Parent', setupLayout, ...
                'String', 'Species:');
            
            obj.ledPopupMenu = MappedPopupMenu( ...
                'Parent', lightLayout, ...
                'String', {' '}, ...
                'HorizontalAlignment', 'left', ...
                'Callback', @obj.onSelectedLed);
            obj.ndfsField = uicontrol( ...
                'Parent', lightLayout, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left', ...
                'Enable', 'off');
            obj.gainField = uicontrol( ...
                'Parent', lightLayout, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left', ...
                'Enable', 'off');
            obj.speciesField = uicontrol( ...
                'Parent', setupLayout, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left', ...
                'Enable', 'off');
            
            Button( ...
                'Parent', lightLayout, ...
                'Icon', App.getResource('icons', 'help.png'), ...
                'Callback', @obj.onSelectedLedHelp);
            Button( ...
                'Parent', lightLayout, ...
                'Icon', App.getResource('icons', 'help.png'), ...
                'Callback', @obj.onSelectedNdfsHelp);
            Button( ...
                'Parent', lightLayout, ...
                'Icon', App.getResource('icons', 'help.png'), ...
                'Callback', @obj.onSelectedGainHelp);
            Button( ...
                'Parent', setupLayout, ...
                'Icon', App.getResource('icons', 'help.png'), ...
                'Callback', @obj.onSelectedSpeciesHelp);
            set(lightLayout, ...
                'Widths', [80 -1 22], ...
                'Heights', [23 23 23 23]);

            


            converterBox = uix.BoxPanel( ...
                'Parent', mainLayout, ...
                'Title', 'Converter', ...
                'BorderType', 'none', ...
                'FontName', get(figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(figureHandle, 'DefaultUicontrolFontSize'), ...
                'Padding', 11);
            converterLayout = uix.Grid( ...
                'Parent', converterBox, ...
                'Spacing', 7);
                    
            Label( ...
                'Parent', converterLayout, ...
                'String', 'Volts')
            
            obj.makePhotoreceptorLabels(converterLayout);

            obj.voltsBox = uicontrol( ...
                'Parent', converterLayout, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left', ...
                'Callback', obj.onVoltsBox);
            
            obj.photoreceptorBoxes = ...
                obj.makePhotoreceptorBoxes(converterLayout);
            S
            set(lightLayout, ...
                'Widths', [80 -1 22], ...
                'Heights', 23 * ones(1,obj.photoreceptors.length));
                        
            set(mainLayout, ...
                'Heights', [125 25 * (obj.photorecepetors.length + 1)]);
        end
        
        function makePhotoreceptorLabels(obj, parent)
           for p = 1:obj.photoreceptors.length
               Label( ...
                   'Parent', parent, ...
                   'String', [obj.orderedPhotoreceptorKeys{p} ' R*/s']);
           end
        end
        
        function boxes = makePhotoreceptorBoxes(obj, parent)
            boxes = containers.Map();
            for p = 1:obj.photoreceptors.length
                boxes(obj.orderedPhotoreceptorKeys{p}) = uicontrol( ...
                    'Parent', parent, ...
                    'Style', 'edit', ...
                    'HorizontalAlignment', 'left', ...
                    'Callback', {@obj.onPhotoreceptorBox, obj.orderedPhotoreceptorKeys{p}});
            end
        end
        
        function orderedKeys = orderPhotoreceptorKeys(obj)
           keys = obj.photoreceptors.keys(); 
           % check for 'rod'
           idx = [];
           for i = 1:numel(keys)
              if strcmpi(keys{i}, 'rod')
                  idx = i;
                  break
              end
           end
           if isempty(idx)
               orderedKeys = sort(keys);
           else
               orderedKeys = [keys{idx} sort(keys((1:numel(keys)) ~= idx))];
           end
        end
    end

    methods (Access = protected)

        function willGo(obj)
            obj.leds = obj.configurationService.getDevices('LED');
            obj.species = obj.findSpecies();

            obj.populateLedList();
            obj.populateNdfs();
            obj.populateGain();
            obj.populateSpecies();
            obj.populatePhotoreceptorList();
        end

        function bind(obj)
            bind@symphonyui.ui.Module(obj);

            obj.bindLeds();

            d = obj.documentationService;
            obj.addListener(d, 'BeganEpochGroup', @obj.onServiceBeganEpochGroup);
            obj.addListener(d, 'EndedEpochGroup', @obj.onServiceEndedEpochGroup);
            obj.addListener(d, 'ClosedFile', @obj.onServiceClosedFile);

            c = obj.configurationService;
            obj.addListener(c, 'InitializedRig', @obj.onServiceInitializedRig);
        end

    end

    methods (Access = private)

        function bindLeds(obj)
            for i = 1:numel(obj.leds)
                obj.ledListeners{end + 1} = obj.addListener(obj.leds{i}, 'SetConfigurationSetting', @obj.onLedSetConfigurationSetting);
            end
        end

        function unbindLeds(obj)
            while ~isempty(obj.ledListeners)
                obj.removeListener(obj.ledListeners{1});
                obj.ledListeners(1) = [];
            end
        end

        function populateLedList(obj)
            names = cell(1, numel(obj.leds));
            for i = 1:numel(obj.leds)
                names{i} = obj.leds{i}.name;
            end

            if numel(obj.leds) > 0
                set(obj.ledPopupMenu, 'String', names);
                set(obj.ledPopupMenu, 'Values', obj.leds);
            else
                set(obj.ledPopupMenu, 'String', {' '});
                set(obj.ledPopupMenu, 'Values', {[]});
            end
            set(obj.ledPopupMenu, 'Enable', appbox.onOff(numel(obj.leds) > 0));
        end

        function onSelectedLed(obj, ~, ~)
            obj.populateNdfs();
            obj.populateGain();
        end

        function onSelectedLedHelp(obj, ~, ~)
            obj.view.showMessage('onSelectedLedHelp');
        end

        function populateNdfs(obj)
            led = get(obj.ledPopupMenu, 'Value');
            if isempty(led)
                set(obj.ndfsField, 'String', '');
            else
                ndfs = led.getConfigurationSetting('ndfs');
                set(obj.ndfsField, 'String', strjoin(ndfs, '; '));
            end
        end

        function onSelectedNdfsHelp(obj, ~, ~)
            obj.view.showMessage('onSelectedNdfsHelp');
        end

        function populateGain(obj)
            led = get(obj.ledPopupMenu, 'Value');
            if isempty(led)
                set(obj.gainField, 'String', '');
            else
                gain = led.getConfigurationSetting('gain');
                set(obj.gainField, 'String', gain);
            end
        end

        function onSelectedGainHelp(obj, ~, ~)
            obj.view.showMessage('onSelectedGainHelp');
        end

        function populateSpecies(obj)
            if isempty(obj.species)
                set(obj.speciesField, 'String', '');
            else
                set(obj.speciesField, 'String', obj.species.label);
            end
        end

        function s = findSpecies(obj)
            s = [];
            if ~obj.documentationService.hasOpenFile()
                return;
            end

            group = obj.documentationService.getCurrentEpochGroup();
            if isempty(group)
                return;
            end

            source = group.source;
            while ~isempty(source) && ~any(strcmp(source.getResourceNames(), 'photoreceptors'))
                source = source.parent;
            end
            s = source;
        end
        
        function p = findPhotoreceptors(obj)
           p = obj.species.getResource('photoreceptors');
        end

        function onSelectedSpeciesHelp(obj, ~, ~)
            obj.view.showMessage('onSelectedSpeciesHelp');
        end

        function populatePhotoreceptorList(obj)
            if isempty(obj.species)
                set(obj.photoreceptorPopupMenu, 'String', {' '});
                set(obj.photoreceptorPopupMenu, 'Values', {[]});
            else
                photoreceptors = obj.species.getResource('photoreceptors');
                set(obj.photoreceptorPopupMenu, 'String', photoreceptors.keys);
                set(obj.photoreceptorPopupMenu, 'Values', photoreceptors.keys);
            end
            set(obj.photoreceptorPopupMenu, 'Enable', appbox.onOff(~isempty(obj.species)));
        end

        function onSelectedPhotoreceptor(obj, ~, ~)
            disp('onSelectedPhotoreceptor');
        end

        function onSelectedPhotoreceptorHelp(obj, ~, ~)
            obj.view.showMessage('onSelectedPhotoreceptorHelp');
        end

        function onServiceBeganEpochGroup(obj, ~, ~)
            obj.species = obj.findSpecies();
            obj.populateSpecies();
            obj.populatePhotoreceptorList();
        end

        function onServiceEndedEpochGroup(obj, ~, ~)
            obj.species = obj.findSpecies();
            obj.populateSpecies();
            obj.populatePhotoreceptorList();
        end

        function onServiceClosedFile(obj, ~, ~)
            obj.species = [];
            obj.populateSpecies();
        end

        function onServiceInitializedRig(obj, ~, ~)
            obj.unbindLeds();
            obj.leds = obj.configurationService.getDevices('LED');
            obj.populateLedList();
            obj.bindLeds();
        end

        function onLedSetConfigurationSetting(obj, ~, ~)
            obj.populateNdfs();
            obj.populateGain();
        end
        
        % converter updates
        function onVoltsBox(obj, ~, ~)
        end
        function onPhotoreceptorBox(obj, ~, ~, photoreceptor)
            
        end
    end

end
