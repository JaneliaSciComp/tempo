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
%             tmp=strfind(p,filesep);
%             n=regexprep(p((tmp(end)+1):end),'-out.*','');
%             p=p(1:tmp(end));
            axFiles=dir(fullfile(p,[n '*.ax']));
            hotPixels={};
            for i=1:length(axFiles)
              try
                FS=h5readatt(fullfile(p,axFiles(1).name),'/hotPixels','FS');
                NFFT=h5readatt(fullfile(p,axFiles(1).name),'/hotPixels','NFFT');
                dT=NFFT/FS/2;
                dF=FS/NFFT/10;  % /10 for brown-puckette
                data=h5read(fullfile(p,axFiles(1).name),'/hotPixels');
              catch
                fid=fopen(fullfile(p,axFiles(i).name),'r');
                fread(fid,3,'uint8');
                fread(fid,2,'uint32');
                dT=ans(2)/ans(1)/2;
                fread(fid,2,'uint16');
                fread(fid,2,'double');
                dF=ans(2);
                data=fread(fid,[4 inf],'double');
                data=data';
                fclose(fid);
              end
              data(:,1)=data(:,1)*dT;
              hotPixels{i}={data(:,[1 2 4]), dT, dF};
            end
            
            obj.updateProgress('Loading events from file...', 0/2)
            s = load(obj.featuresFilePath, '-ascii');
            
            obj.updateProgress('Adding events...', 1/2)
            for i = 1:size(s, 1)
                if((i==1) && ~isempty(hotPixels))
                  features{end + 1} = Feature('Vocalization', s(i,1:4), ...
                                    'HotPixels', hotPixels); %#ok<AGROW>
                else
                  features{end + 1} = Feature('Vocalization', s(i,1:4)); %#ok<AGROW>
                end
            end
        end
        
    end
    
end
