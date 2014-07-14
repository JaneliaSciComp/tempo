classdef MouseVocImporter < FeaturesImporter
    
    properties
    end
    
    
    methods(Static)
        
        function n = typeName()
            n = 'Mouse Vocalization';
        end
        
        function ft = possibleFeatureTypes()
            ft = {'Vocalization'};
        end
        
        function c = canImportFromPath(featuresFilePath)
            c = false;
            
            if exist(featuresFilePath, 'file')
                [~, name, ext] = fileparts(featuresFilePath);
                if strncmp(ext, '.voc', 4) || strcmp([name ext],'voc.txt')
                    voclist=load(featuresFilePath,'-ascii');
                    if size(voclist,2) == 4
                        c = true;
                    end
                end
            end
        end
    end
    
    
    methods
        
        function obj = MouseVocImporter(controller, featuresFilePath)
            obj = obj@FeaturesImporter(controller, featuresFilePath);
        end
        
        
        function features = importFeatures(obj)
            features = {};

            [p,n,~]=fileparts(obj.featuresFilePath);
            tmp=strfind(p,filesep);
            n=regexprep(p((tmp(end)+1):end),'-out.*','');
            p=p(1:tmp(end));
            tmp=dir(fullfile(p,[n '*.ax']));
            hotpixels={};
            for i=1:length(tmp)
              fid=fopen(fullfile(p,tmp(i).name),'r');
              fread(fid,3,'uint8');
              fread(fid,2,'uint32');
              dT=ans(2)/ans(1)/2;
              fread(fid,2,'uint16');
              fread(fid,2,'double');
              dF=ans(2);
              foo=fread(fid,[4 inf],'double');
              foo(1,:)=foo(1,:)*dT;
              hotpixels{i}={foo([1 2 4],:)', dT, dF};
              fclose(fid);
            end
            
            obj.updateProgress('Loading events from file...', 0/2)
            s = load(obj.featuresFilePath, '-ascii');
            
            obj.updateProgress('Adding events...', 1/2)
            for i = 1:size(s, 1)
                if((i==1) && ~isempty(hotpixels))
                  features{end + 1} = Feature('Vocalization', s(i,1:4), ...
                                    'HotPixels', hotpixels); %#ok<AGROW>
                else
                  features{end + 1} = Feature('Vocalization', s(i,1:4)); %#ok<AGROW>
                end
            end
        end
        
    end
    
end
