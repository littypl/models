classdef PCDSystem2D < models.pcd.BasePCDSystem
    %PCDSystem2D The programmed cell death model for 2D geometry.
    % 
    % The first row of Omega denotes the width of the geometry and
    % the second the height.
    %
    % @change{0,3,sa,2011-05-11} Implemented property setter
    
    properties
        % Flag that indicates if the plot command yields a 2D plot or a 1D slice over time
        % plot.
        %
        % @type logical @default false
        Plot2D = false;
    end
    
    methods
        function this = PCDSystem2D(model)
            this = this@models.pcd.BasePCDSystem(model);
            
            % Set core function
            this.f = models.pcd.CoreFun2D(this);
            
            % Spatial area (unscaled!)
            this.Omega = [0 1.5; 0 1] * this.Model.L;
            
            % Scaled!
            this.h = .5 * this.Model.L;
        end
        
        function varargout = plot(~, model, t, y, varargin)
            if ~isempty(varargin) && isa(varargin{1},'PlotManager')
                pm = varargin{1};
            else
                pm = PlotManager;
                if nargout == 0
                    pm.LeaveOpen = true;
                else
                    varargout{1} = pm;
                end
            end
            h = pm.nextPlot([model.SaveTag '_outputplot'],...
                sprintf('Output plot for model %s',model.Name),'Time','Caspase-3 Concentration');
            %plot(h,t,y,'r','LineWidth',2);
            semilogy(h,t,y,'r','LineWidth',2);
            if isempty(varargin)
                pm.done;
            end
        end
        
        function varargout = plotState(this, model, t, y, varargin)
            if ~isempty(varargin) && isa(varargin{1},'PlotManager')
                pm = varargin{1};
            else
                pm = PlotManager(false,2,2);
                if nargout == 0
                    pm.LeaveOpen = true;
                else
                    varargout{1} = pm;
                end
            end
            if this.Plot2D
                this.plot2DState(model, t, y, pm);
            else
                this.plot1DState(model, t, y, pm);
            end
            if isempty(varargin)
                pm.done;
            end
        end
    end
    
    methods(Access=protected)     
        function newSysDimension(this)
            m = prod(this.Dims);
            x0 = zeros(4*m,1);
            x0(1:2*m) = 1e-16; % use 5e-13 for pcd 2d exps
            x0(2*m+1:end) = 1e-9; % use 3e-8 for pcd 2d exps
            this.x0 = dscomponents.ConstInitialValue(x0);
            
            % Diffusion part
            A = MatUtils.laplacemat(this.hs, this.Dims(1), this.Dims(2));
            A = blkdiag(A,this.Diff(1)*A,this.Diff(2)*A,this.Diff(3)*A);
            this.A = dscomponents.LinearCoreFun(A);
            
            % Output extraction
            p = .1; % 10% of each dimensions span, centered in geometry.
            d = this.Dims(1);
            d1idx = find(abs((1:d) - d/2) <= d/2 * p);
            if isempty(d1idx)
                d1idx = 1;
            end
            d = this.Dims(2);
            d2idx = find(abs((1:d) - d/2) <= d/2 * p);
            if isempty(d2idx)
                d2idx = 1;
            end
            [d1,d2] = meshgrid(d1idx,d2idx);
            sel = reshape(sub2ind(this.Dims,d1,d2),1,[]);
            C = sparse(1,4*m);
            ca3 = m+1:2*m;
            C(ca3(sel)) = 1/length(sel);
            this.C = dscomponents.LinearOutputConv(C);
        end
    end
    
    methods(Access=private)
        function plot1DState(this, model, t, y, pm)
            m = prod(this.Dims);
            
            % Select cell center values
            idxmat = zeros(this.Dims);
            idxmat(:) = 1:m;
            sel = idxmat(:,round(this.Dims(2)/2));
            sel = [sel; sel+m; sel+2*m; sel+3*m];
            m = length(sel)/4;
            y = y(sel,:);
            
            if length(t) > 150
                idx = round(linspace(1,length(t),150));
                t = t(idx);
                y = y(:,idx);
            end
            states = {'alive','unstable','dead'};
            
            X = t;
            Y = (this.Omega(1,1):this.h:this.Omega(1,2))/model.L;
            doplot(y(1:m,:),'c8','Caspase-8 (x_a)',1);
            doplot(y(m+1:2*m,:),'c3','Caspase-3 (y_a)',2);
            doplot(y(2*m+1:3*m,:),'pc8','Pro-Caspase-8 (x_i)',3);
            doplot(y(3*m+1:end,:),'pc3','Pro-Caspase-3 (y_i)',4);
            
            function doplot(y, tag, thetitle, pnr)
                di = abs(this.Model.SteadyStates(:,pnr)-y(end));
                reldi = di ./ (this.Model.SteadyStates(:,pnr)+eps);
                reldistr = Utils.implode(reldi,', ','%2.3e');
                if any(reldi > .1) || any(reldi < 10)
                    [~, id] = min(di);
                    tit = sprintf('Model "%s", %s concentrations\nCell state at T=%d: %s\n%s', model.Name, thetitle,...
                    max(t),states{id},reldistr);
                else
                    tit = sprintf('Model "%s", %s concentrations\n%s', model.Name, thetitle,reldistr);
                end
                h = pm.nextPlot(tag,tit,'Time [s]','Cell slice');
                surf(h,X,Y,y,'EdgeColor','none');
                zlabel(h,thetitle);
            end
        end

        function plot2DState(this, model, t, v, pm)
            % Performs a plot for this model's results.
            %
            % Parameters:
            % t: The times `t_0,\ldots,t_N` as row vector @type rowvec
            % v: The system's caspase concentrations (with no output
            % projection!) @type matrix
            
            autocols = true;
            
            m = prod(this.Dims);
            xa = v(1:m,:);
            ya = v(m+1:2*m,:);
            xi = v(2*m+1:3*m,:);
            yi = v(3*m+1:end,:);
            b = [min(xa(:)) max(xa(:)); min(ya(:)) max(ya(:));...
                 min(xi(:)) max(xi(:)); min(yi(:)) max(yi(:))];
            %% Prepare figures
            rotate3d on;
            hlpf = figure('Visible','off','MenuBar','none','ToolBar','none');
            hlpax = newplot(hlpf);
            axis tight;
            ax = [];
            caps = {'Caspase-8','Caspase-3','Pro-Caspase-8','Pro-Caspase-3'};
            for p = 1:4
                h = pm.nextPlot(sprintf('PCD2D_plot1D_%d',p),...
                    sprintf('Model "%s", %s concentrations', model.Name, caps{p}),...
                    'Left to right','Bottom to Top');
                axis(h,[reshape(this.Omega',1,[]) b(p,:)]);
                ar = get(gca,'DataAspectRatio');
                set(h,'DataAspectRatio',[ar(1)/2 ar(2:3)]);
                %axis(a fill;
                set(h,'Box','on','GridLineStyle','none');
                if ~autocols
                    set(h,'CLimMode','manual','CLim',b(p,:));
                end
                view(h,-22,31);
                zlabel(h,sprintf('%s concentration',caps{p}));
                colorbar('peer',h);
                ax(end+1) = h;%#ok
            end
            
            %% Plot timesteps
            a = this.Omega;
            x = a(1,1):this.h:a(1,2);
            y = a(2,1):this.h:a(2,2);
            [X,Y] = meshgrid(x,y);
            
            step = round(length(t)/40);
            for idx=1:step:length(t)
                h1 = doplot(xa(:,idx),ax(1));
                h2 = doplot(ya(:,idx),ax(2));
                h3 = doplot(xi(:,idx),ax(3));
                h4 = doplot(yi(:,idx),ax(4));
                set(gcf,'Name',sprintf('Plot at t=%f',t(idx)));
                if idx ~= length(t)
                    pause;
                    delete([h1; h2; h3; h4]);
                end
            end
            
            close(hlpf);
            
            function hs = doplot(zd, ax)       
                V = reshape(zd,this.Dims(1),[])';
                                
                % bugfix: constant nonzero values cause slice to crash when
                % setting the clim property.
%                 if V(1) ~= 0 && all(V(1) == V(:))
%                     V(1) = 1.0001*V(1);
%                 end
                %hs = mesh(hlpax,X,Y,V);
                hs = surf(hlpax,X,Y,V);
                set(hs,'Parent',ax);
                set(hs,'FaceColor','interp','EdgeColor','none');
            end
        end
    end
    
end

