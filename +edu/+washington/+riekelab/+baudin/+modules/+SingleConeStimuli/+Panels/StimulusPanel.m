classdef StimulusPanel < edu.washington.riekelab.baudin.modules.SingleConeStimuli.Panels.Panel
    properties
        selectableConeCircles
    end
    
    properties (Constant)
        BUTTON_HEIGHT = 30;
        TITLE_HEIGHT = 18;
    end
    
    methods
        function obj = StimulusPanel(parentBox, tabPanel, controller)
            obj = obj@edu.washington.riekelab.baudin.modules.SingleConeStimuli.Panels.Panel(parentBox, tabPanel, controller);
            obj.imageBox.setTitle('Perform cone typing.');
            obj.createButtonBox();
            addlistener(obj.controller, 'updatedTyping', @obj.onUpdatedTyping);
        end
        
        function activate(obj)
            obj.imageBox.displayImage(obj.controller.getConeMap());
            obj.imageBox.getImageObj().ButtonDownFcn = @obj.onClickedImage;
        end
        
        function createButtonBox(obj)
            % create a button for add stimulus to selected, clear from
            % selected, clear all, deliver stimulus
            import appbox.*;
            
            uix.Empty( ...
                'Parent', obj.buttonsBox);
            
            uicontrol( ...
                'Parent', obj.selectConesBox, ...
                'Style', 'Text', ...
                'String', 'For selected cones:');
            
            uix.Empty( ...
                'Parent', obj.buttonsBox);
            
            edu.washington.riekelab.baudin.modules.SingleConeStimuli.Utils.addFlankedByEmptyHorizontal( ...
                @uicontrol, obj.buttonsBox, obj.FLANKED_BUTTON_WIDTHS, ...
                'Style', 'pushbutton', ...
                'String', 'Add Stimulus', ...
                'Visible', 'off', ...
                'Callback', @obj.onAddStimulus);
            
            uix.Empty( ...
                'Parent', obj.buttonsBox);
            
            edu.washington.riekelab.baudin.modules.SingleConeStimuli.Utils.addFlankedByEmptyHorizontal( ...
                @uicontrol, obj.buttonsBox, obj.FLANKED_BUTTON_WIDTHS, ...
                'Style', 'pushbutton', ...
                'String', 'Clear Stimulus', ...
                'Visible', 'off', ...
                'Callback', @obj.onClearStimulusOnSelected);
            
            uix.Empty( ...
                'Parent', obj.buttonsBox);
            
            edu.washington.riekelab.baudin.modules.SingleConeStimuli.Utils.addFlankedByEmptyHorizontal( ...
                @uicontrol, obj.buttonsBox, obj.FLANKED_BUTTON_WIDTHS, ...
                'Style', 'pushbutton', ...
                'String', 'View Stimulus', ...
                'Visible', 'off', ...
                'Callback', @obj.onViewStimulusOnSelected);
            
            uix.Empty( ...
                'Parent', obj.buttonsBox);
            
        end
        
        function drawConeCircles(obj)
            [centers, radii] = obj.controller.constructConeLocationMatrices();
            types = obj.controller.getConeTypes();
            obj.selectableConeCircles = ...
                edu.washington.riekelab.baudin.modules.SingleConeStimuli.Utils.SelectableConeCircles( ...
                centers, radii, types, obj.imageBox.getImageAxes());
            
        end
        
        function onUpdatedTyping(obj, ~, ~)
            % clear current selections/stimuli and redraw cone circles
            obj.selectableConeCircles.delete();
            obj.drawConeCircles();
        end
        
        function onClickedImage(obj, ~, ~)
            pos = obj.imageAxes.CurrentPoint(1, 1:2);
            obj.selectableConeCircles.handleClicke(pos);
        end
        
        function onClearSelection(obj, ~, ~)
            obj.selectableConeCircles.clearSelection();
        end
        
        function onAddStimulus(obj, ~, ~)
            [protocolName, propertyMap] = obj.controller.getCurrentProtocol();
            obj.selectableConeCircles.addStimulusToSelected(protocolName, propertyMap);
        end
        
        function onDeliverStimulus(obj, ~, ~)
            obj.controller.deliverStimulus(obj.selectableConeCircles.collectStimuli());
        end
        
        function onViewStimulusOnSelected(obj, ~, ~)
            stimulus = obj.selectableConeCircles.getStimulusIfSingleConeSelected();
            if ~isempty(propertyName)
                obj.controller.viewStimulus(stimulus);
            end
        end
        
        function onClearStimulusOnSelected(obj, ~, ~)
            obj.selectableConeCircles.clearStimulusOnSelected();
        end
        
        function onClearAllStimuli(obj, ~, ~)
            obj.selectableConeCircles.clearAllStimuli();
        end
    end
end