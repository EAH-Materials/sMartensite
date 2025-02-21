%% Import Script for EBSD Data
%
% This script was automatically created by the import wizard. You should
% run the whoole script or parts of it in order to import your data. There
% is no problem in making any changes to this script.

% Das hier muss nur einmal ausgeführt werde nachdem Matlab gestartet wurde. 
% Alternativ kannst du auch eine Datei "startup.m" erstellen im Default-Matlab Ordner
% (<UserDirectory>/Dokumente/MATLAB/) und die Zeilen da rein kopieren (mit
% dem korrekten Pfad zu mtex

% addpath 'mtex\mtex'
% startup_mtex

%% Specify Crystal and Specimen Symmetries

clear;
% crystal symmetry
% Die Reihenfolge der Phasen muss mit der Nummerierung im ctf-file
% übereinstimmen. Die letzten beiden Phasennnnnnn werden als Dummies
% hinzugefügt. Die brauchen wir als Platzhalter für die manuelle Zuordnung
% der Phasen
CS = {... 
  % crystalSymmetry('1', [NaN NaN NaN], [NaN,NaN,NaN]*degree, 'mineral', 'notIndexed','color', [0.0 0.0 0.0]),...
  crystalSymmetry('m-3m', [3.6 3.6 3.6], 'mineral', 'Austenite', 'color', [0.56 0.74 0.56]),...
  crystalSymmetry('m-3m', [2.9 2.9 2.9], 'mineral', 'Thermal Martensite', 'color', [0.53 0.81 0.98]),...
  crystalSymmetry('mmm', [5.1 6.8 4.5], 'mineral', 'Cementite', 'color', [0.85 0.65 0.13]),...
  crystalSymmetry('m-3m', [2.9 2.9 2.9], 'mineral', 'Mechanically induced Martensite', 'color', [0.63 0.81 0.98]),...
  crystalSymmetry('m-3m', [2.9 2.9 2.9], 'mineral', 'Surface Martensite', 'color', [0.73 0.81 0.98])};

% plotting convention
setMTEXpref('xAxisDirection','east');
setMTEXpref('zAxisDirection','intoPlane')
%% Specify File Names

% path to files (directory and filename)
pname = ['data' filesep 'raw' filesep 'ctfs'];
file = '120_100°C_100C_00.ctf';
fname = [pname filesep file];

%% Import the Data
% create an EBSD variable containing the data
ebsd = EBSD.load(fname,CS,'interface','ctf',...
  'convertEuler2SpatialReferenceFrame');

%% reconstruct grains
[grains, ebsd.grainId] = calcGrains(ebsd,'alpha',2.2,'angle',10*degree,'minPixel',8);...;
% TODO: Besser machen :)
% https://mtex-toolbox.github.io/EBSDPlotting.html

ebsd(grains(and(grains.phase ~= 2, grains.grainSize<35))) = [];

[grains,ebsd.grainId] = calcGrains(ebsd);
F = splineFilter;
ebsd = smooth(ebsd,F,'fill');
[grains,ebsd.grainId] = calcGrains(ebsd);
plot(ebsd)
hold on
plot(grains.boundary,'linewidth',1)
hold off

%% Plot stuff
% Neue figure
f = figure(2); clf();
%  Plot Band contrast in schwarz-weiß
plot(ebsd,ebsd.bc); 
mtexColorMap black2white
hold on;

% Filtern der Körner nach Größe und Phase
mart_Grains = grains(and(grains.phase == 2, grains.grainSize>150));

% Weise Orientierungen der Martensitphase Farben zu
ipfKey = ipfColorKey(mart_Grains.phase);
ipfKey.inversePoleFigureDirection = vector3d.Z;
colors = ipfKey.orientation2color(ebsd(mart_Grains).orientations);

% Überlagere das Band-Kontrast Bild mmit Orientierungsfarben
plot(ebsd(mart_Grains),colors,'FaceAlpha',0.5)

% bnd steht für baoundaries (Korngrenzen)
bnd = plot(mart_Grains.boundary,'linewidth',2,'linecolor','b');

% Abfrageprompt zum Labeln der Martensitkörner
prompt = "What itype is the Martensite? (1: thermal, 2: mechanical, 3: Surface)";

% Schleife über alle Martensitkörner. 
% TODO:
% Da wir nun für jedes Korn die Pixelpositionen kennen und einen Typen zuweisen, 
% können wir eine Art Phasenmap erstellen, in der wir jedem Pixel im Bild
% einen Wert zuweisen können
phaseMap = get_dummy_image(ebsd);

% Setze Phase 1 für Austenit
phaseMap(ebsd.phase == 1) = 1;

% Weise Martensitkörner interaktiv zu
plot_grain_padding = 30;
for id = 1:size(mart_Grains)
   delete(bnd)
   bnd = plot(mart_Grains(id).boundary,'linewidth',1,'linecolor','r');
   xlim([max(min(mart_Grains(id).x)-plot_grain_padding,0) min(max(mart_Grains(id).x)+plot_grain_padding,size(phaseMap,1))]);
   ylim([max(min(mart_Grains(id).y)-plot_grain_padding,0) min(max(mart_Grains(id).y)+plot_grain_padding,size(phaseMap,2))]);
   phase = min(input(prompt)*2,5); % gibt 2, 4 oder 5 (Cementit ist dazwischen auf 3)
   ebsd(mart_Grains(id)).phase = phase;
end
hold off;

% Plotte die gelabelten Phasen
phaseMap(:) = ebsd.phase; 
figure(2); clf;
imagesc(phaseMap');
axis image
cmap = lines(6);
colormap(cmap);
val_keys = {'Not indexed';'Austenite';'Th. Mart.';'Cementite';'Mech. Mart.';'Surf. Mart'};
colorbar('Ticks', linspace(0.5,5.2,7), 'TickLabels', val_keys)
title('Assigned Label')

%%   Save Stuff
[path, filename, ext] = fileparts(fname);
save([filename '_label.mat'],"phaseMap","val_keys");

%% Functions
% Diese Funktion erstellt nur ein leeres 2D array (ein Bild mit Nullen
% quasi) in der Größe der EBSD-Map
function img = get_dummy_image(ebsd,type)
    if nargin < 2
        type = 'uint8';
    end
    nx = size(unique(ebsd.prop.x),1);
    ny = size(unique(ebsd.prop.y),1);
    img = zeros(nx,ny,type);
end
