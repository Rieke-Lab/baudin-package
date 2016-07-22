classdef GainController < symphonyui.ui.Module
   
    properties
       leds 
       figureHandle
       ledListeners
       
       % ui components
       ledTitles
       gainButtons
       gainStrings
    end       
    
    
    properties (Constant)
        RED_SELECTED = [1 0.2 0.2]
        GREEN_SELECTED = [0.2 1 0.2]
        BLUE_SELECTED = [0.2 0.2 1]
        UV_SELECTED = [0.8 0.5 1]
    end
    
    methods
        function createUI(obj, figureHandle)
            obj.figureHandle = figureHandle;
        end
        
        function populateUI(obj)
            % add LEDs and their current gains
            
        end

    end
    
    methods (Access = protected)
        function willGo(obj)
            obj.leds = obj.configurationService.getDevices('LED');
            obj.populateUI();
        end
        
        function bind(obj)
            bind@symphonyui.ui.Module(obj);
            
            obj.bindLeds();
                       
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
        
        function onServiceInitializedRig(obj)
            % flush out and reset everything
            obj.unbindLeds();
            obj.leds = obj.configurationService.getDevices('LED');
            obj.bindLeds();
            obj.populateUI();
        end
        
        function markSelected(obj)
        
        
    end
    
    
    
end