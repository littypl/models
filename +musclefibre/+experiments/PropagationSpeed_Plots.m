%% Clear
clear classes;

distN = 100; % The number of sarcomeres over which to measure the propagation speed.
Tfinal = 5000;
dt = .01;
usenoise = false;

%% General
% minV = -20; %[mV]

%% Crunch
base = fullfile(KerMor.App.DataDirectory,'musclefibre','propagationspeed');
tag = sprintf('N%d_T%d_dt%g_noise%d',distN,Tfinal,dt,usenoise);
thefile = ['data_' tag '.mat'];
load(fullfile(base,thefile));
m = models.musclefibre.Model('N',N,'SarcoVersion',1,'Noise',usenoise);
sys = m.System;
len = distN*sys.dx;

%% Process
[T,V,tgrid,Vinterp,Vpoly,invalid] = models.musclefibre.experiments.getVelocities(0:dt:Tfinal, Vms, len);
mus(:,invalid) = [];
nmu = size(mus,2);

%% Plot failure runs
for k=invalid
    Vm = Vms{k};
    ax = pm.nextPlot(sprintf('fail_%d_%s',k,tag),...
        sprintf('mu=[%g %g], |T{k}|=%d',mus(:,k),length(T{k})),'time','velocity');
    plot(ax,t,Vm(1,:),'r',t,Vm(2,:),'b');
end

%% SVR
% svr = general.regression.ScalarNuSVR;
% svr.nu = .1;
% svr = general.regression.ScalarEpsSVR;
% svr = general.regression.ScalarEpsSVR_SMO;
% svr.Lambda = 0.0005;
% svr.Eps = .01;
% k = kernels.GaussKernel(100);
% %k = kernels.Wendland; k.d = 1; k.k = 3; k.Gamma = 100;
% %kexp = svr.directCompute(k,P{idx},V{idx});
% afx = kexp.evaluate(P{idx});
% tgrid = linspace(0,m.T,1000);
% afx2 = kexp.evaluate(tgrid);
% c = polyfit(P{idx},V{idx},2);
% apol = polyval(c,tgrid);
% plot(P{idx},V{idx},'rx',tgrid,afx2,'b',P{idx},afx,'g',tgrid,apol,'m');

%% Draw
numi = 1000;
pm = PlotManager;
data = Vinterp;
ax = pm.nextPlot('avgspeed','Average speed (of interpolated velocities) over time for all parameters','time [ms]','speed [m/s]');
plot(ax,tgrid,mean(data,1));
ax = pm.nextPlot('propspeed','Action potential propagation speed [m/s]','fibre type','mean input current');
tri = delaunay(mus(1,:),mus(2,:));
minV = min(data(:));
maxV = max(data(:));

%% Draw 2
for idx = 1:numi
    if ~ishandle(ax)
        break;
    end
    trisurf(tri,mus(1,:),mus(2,:),data(:,idx),...
        'FaceColor','interp','EdgeColor','interp','Parent',ax);
    zlim(ax,[minV maxV]);
    view(ax,[-150 0]);
    title(sprintf('Action potential propagation speed [m/s] at %gs',tgrid(idx)));
    drawnow;
    pause(.01);        
end
pm.done;

%% Plot discrete signals
pm = PlotManager(false,4,4);
sel1 = find(mus(2,:) > 3);
[~,sel1_sort] = sort(mus(1,sel1),'ascend');
sel1 = sel1(sel1_sort);
nvm = length(sel1);
avgs = zeros(1,nvm);
for idx=1:nvm
    k = sel1(idx);
    avgs(idx) = mean(V{k});
    ax = pm.nextPlot(sprintf('ps_%s_part%d-%d',tag,k,k+15),...
        sprintf('mu=[%g %g], avg v=%g [m/s]',mus(:,k),...
            avgs(idx)),'time','velocity');
    plot(ax,T{k},V{k});
    drawnow;
end

%% Plot
pm = PlotManager(false,2,3);
pm.ExportDPI = 300;
nvm = length(Vms);
for k=1:nvm
    Vm = Vms{k};
    avgs(k) = mean(V{k});
    ax = pm.nextPlot(sprintf('ps_%s_part%d-%d',tag,k,k+5),...
        sprintf('len=%g, avg v=%g [m/s]',len,...
            avgs(k)),'time','Vm');
    plot(ax,t,Vm(1,:),'r',t,Vm(2,:),'b');
end
%%
pm.savePlots(base,'Format',{'jpg','pdf','fig'},'Close',true);
%%
pm = PlotManager;
pm.ExportDPI = 300;
ax = pm.nextPlot(tag,sprintf('SpeedConvergence test %s',...
        tag),'N','average speed [m/s]'); %length [cm]
%plot(ax,measurelengths,avgs);
plot(ax,N-20,avgs);
%%
pm.savePlots(base,'Format',{'jpg','pdf','fig'},'Close',true);
%%
% [~,sidx] = sort(mus(1,:),'ascend');
% [X_,Y_] = meshgrid(mus(1,sidx),tgrid);
% mesh(X_,Y_,Vinterp(sidx,:));
% mesh(Vinterp(sidx,:));
% mesh(Vpoly(sidx,:));

