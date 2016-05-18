classdef IsomerizationsConverter < symphonyui.ui.Module

    properties
        leds
        ledListeners
        species
    end

    properties
        ledPopupMenu
        ndfsField
        gainField
        speciesField
        photoreceptorPopupMenu
    end

    methods

        function createUi(obj, figureHandle)
            import appbox.*;
            import symphonyui.app.App;

            set(figureHandle, ...
                'Name', 'Isomerizations Converter', ...
                'Position', screenCenter(270, 304));

            mainLayout = uix.VBox( ...
                'Parent', figureHandle);

            lightBox = uix.BoxPanel( ...
                'Parent', mainLayout, ...
                'Title', 'Light', ...
                'BorderType', 'none', ...
                'FontName', get(figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(figureHandle, 'DefaultUicontrolFontSize'), ...
                'Padding', 11);
            lightLayout = uix.Grid( ...
                'Parent', lightBox, ...
                'Spacing', 7);
            Label( ...
                'Parent', lightLayout, ...
                'String', 'LED:');
            Label( ...
                'Parent', lightLayout, ...
                'String', 'NDFs:');
            Label( ...
                'Parent', lightLayout, ...
                'String', 'Gain:');
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
            set(lightLayout, ...
                'Widths', [80 -1 22], ...
                'Heights', [23 23 23]);

            targetBox = uix.BoxPanel( ...
                'Parent', mainLayout, ...
                'Title', 'Target', ...
                'BorderType', 'none', ...
                'FontName', get(figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(figureHandle, 'DefaultUicontrolFontSize'), ...
                'Padding', 11);
            targetLayout = uix.Grid( ...
                'Parent', targetBox, ...
                'Spacing', 7);
            Label( ...
                'Parent', targetLayout, ...
                'String', 'Species:');
            Label( ...
                'Parent', targetLayout, ...
                'String', 'Photoreceptor:');
            obj.speciesField = uicontrol( ...
                'Parent', targetLayout, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left', ...
                'Enable', 'off');
            obj.photoreceptorPopupMenu = MappedPopupMenu( ...
                'Parent', targetLayout, ...
                'String', {' '}, ...
                'HorizontalAlignment', 'left', ...
                'Callback', @obj.onSelectedPhotoreceptor);
            Button( ...
                'Parent', targetLayout, ...
                'Icon', App.getResource('icons', 'help.png'), ...
                'Callback', @obj.onSelectedSpeciesHelp);
            Button( ...
                'Parent', targetLayout, ...
                'Icon', App.getResource('icons', 'help.png'), ...
                'Callback', @obj.onSelectedPhotoreceptorHelp);
            set(targetLayout, ...
                'Widths', [80 -1 22], ...
                'Heights', [23 23]);

            converterBox = uix.BoxPanel( ...
                'Parent', mainLayout, ...
                'Title', 'Converter', ...
                'BorderType', 'none', ...
                'FontName', get(figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(figureHandle, 'DefaultUicontrolFontSize'), ...
                'Padding', 11);
            converterLayout= uix.HBox( ...
                'Parent', converterBox);
            isomsLayout = uix.VBox( ...
                'Parent', converterLayout);
            uicontrol( ...
                'Parent', isomsLayout, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left');
            Label( ...
                'Parent', isomsLayout, ...
                'String', 'isom/s', ...
                'HorizontalAlignment', 'center');
            set(isomsLayout, 'Heights', [23 23]);
            arrowLayout = uix.VBox( ...
                'Parent', converterLayout);
            Label( ...
                'Parent', arrowLayout, ...
                'String', '<html>&#x2194;</html>', ...
                'HorizontalAlignment', 'center');
            uix.Empty('Parent', arrowLayout);
            set(arrowLayout, 'Heights', [23 -1]);
            voltsLayout = uix.VBox( ...
                'Parent', converterLayout);
            uicontrol( ...
                'Parent', voltsLayout, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left');
            Label( ...
                'Parent', voltsLayout, ...
                'String', 'volts', ...
                'HorizontalAlignment', 'center');
            set(voltsLayout, 'Heights', [23 23]);
            set(converterLayout, 'Widths', [-1 23 -1]);

            set(mainLayout, 'Heights', [125 95 95]);
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

    end

end
