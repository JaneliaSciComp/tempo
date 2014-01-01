function Tempo()
    if verLessThan('matlab', '7.12')
        error 'Tempo requires MATLAB 7.12 (2011a) or later.'
    end
    
    % TODO: implement app-level features like window menu, etc.
    
    TempoController();
    return
end
