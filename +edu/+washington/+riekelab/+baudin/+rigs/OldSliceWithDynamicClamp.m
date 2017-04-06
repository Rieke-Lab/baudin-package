classdef OldSliceWithDynamicClamp < symphonyui.core.descriptions.RigDescription
    
    methods
        
        function obj = OldSliceWithDynamicClamp()
            import symphonyui.builtin.daqs.*;
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            import edu.washington.*;
            
            daq = HekaDaqController();
            obj.daqController = daq;
            
            amp1 = MultiClampDevice('Amp1', 1).bindStream(daq.getStream('ao0')).bindStream(daq.getStream('ai0'));
            obj.addDevice(amp1);

            temperature = UnitConvertingDevice('Temperature Controller', 'V', 'manufacturer', 'Warner Instruments').bindStream(daq.getStream('ai6'));
            obj.addDevice(temperature);
            
            trigger = UnitConvertingDevice('Oscilloscope Trigger', Measurement.UNITLESS).bindStream(daq.getStream('doport1'));
            daq.getStream('doport1').setBitPosition(trigger, 0);
            obj.addDevice(trigger);
            
            %DYNAMIC CLAMP STUFF
            currentInjected = UnitConvertingDevice('Injected current', 'V').bindStream(obj.daqController.getStream('ai1'));
            obj.addDevice(currentInjected);
            
            gExc = UnitConvertingDevice('Excitatory conductance', 'V').bindStream(daq.getStream('ao2'));
            obj.addDevice(gExc);
            gInh = UnitConvertingDevice('Inhibitory conductance', 'V').bindStream(daq.getStream('ao3'));
            obj.addDevice(gInh);
        end
        
    end
    
end