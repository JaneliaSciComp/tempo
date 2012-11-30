classdef MediaPanel < AnalysisPanel
	
	properties
		recording
	end
	
	methods
		
		function obj = MediaPanel(controller, recording)
			obj = obj@AnalysisPanel(controller);
			
			obj.recording = recording;
		end
		
	end
	
end
