classdef FeaturesPanel < TimelinePanel

	properties
        reporter
	end
	
	methods
	
		function obj = FeaturesPanel(controller, reporter)
			obj = obj@AnalysisPanel(controller);
            
            obj.reporter = reporter;
            
            obj.axesBorder = [0 0 16 0];
		end
	
	end
	
end
