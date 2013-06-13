function Tempo()
    if verLessThan('matlab', '7.9')
        error 'Tempo requires MATLAB 7.9 (2009b) or later.'
    end
    
    % TODO: implement app-level features like window menu, etc.
    
    AnalysisController();
    return
end
