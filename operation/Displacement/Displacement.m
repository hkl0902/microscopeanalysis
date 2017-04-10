classdef Displacement < Operation
    %VIDPLAY Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Access = private) 
        vid_src;
        %rgb, intensity, none
        vid_colorspace;
        axes;
        pixel_precision;
        max_displacement;
        valid;
        template; rect; xtemp; ytemp;
        current_frame;
        table;
        img_cover;
        pause_button;
        table_data;
        stop_check_callback = @check_stop;
        im;
        in_buffer;
    end

    properties (SetAccess = public)
        pause_bool;
        outputs = {};
        inputs = {};
    end
    
    properties (Constant)
        VID_HEIGHT = 1024;
        VID_WIDTH = 1280;
        rx_data = {};
        insertion_type = 'end';
        num_args_in = 0;
        num_args_out = 0;
        dependents = {};
    end
    
    methods(Static)
        function string = name(obj)
            string = 'VideoPlayer: ';
        end
    end

    methods
        function obj = Displacement(src, axes, table, img_cover, pause_button, colorspace, pixel_precision, max_displacement)
            obj.vid_src = src;
            obj.axes = axes;
            obj.table = table;
            obj.img_cover = img_cover;
            obj.pause_button = pause_button;
            obj.vid_colorspace = colorspace;
            obj.pause_bool = false;
            obj.pixel_precision = str2double(pixel_precision);
            obj.max_displacement = str2double(max_displacement);
            obj.startup();
            obj.in_buffer = {};
        end

        %For carrying out one time method calls that should be done before
        %calling of execute
        function startup(obj)
            set(obj.img_cover, 'Visible', 'Off');
            set(obj.pause_button, 'Visible', 'On');
            obj.initialize_algorithm();
            obj.table_data = {'DispX'; 'DispY'};
            obj.im = zeros(obj.vid_src.get_resolution());
            obj.im = imshow(obj.im);
        end
        
        function initialize_algorithm(obj)
            obj.current_frame = gather(grab_frame(obj.vid_src, obj));
            [obj.template, obj.rect, obj.xtemp, obj.ytemp] = get_template(obj.current_frame, obj.axes);
        end
        
        function execute(obj)
              disp('ACQUIRE FRAME AND MEAS_DISPLACEMENT')
              tic;
              obj.current_frame = grab_frame(obj.vid_src, obj);
              if(strcmp(VideoSource.getSourceType(obj.vid_src), 'file'))
                [xoffSet, yoffSet, dispx,dispy,x, y] = meas_displacement_gpu_array(obj.template,obj.rect,obj.current_frame, obj.xtemp, obj.ytemp, obj.pixel_precision, obj.max_displacement);
              else
                [xoffSet, yoffSet, dispx,dispy,x, y, ~] = meas_displacement_subpixel_gpu_array(obj.template,obj.rect,obj.current_frame, obj.xtemp, obj.ytemp, obj.max_displacement);
              end
              disp(toc);
              disp('DRAW_RECT');
              tic;
              draw_rect(obj.current_frame, obj.im, xoffSet, yoffSet, obj.template, obj.axes);
              disp(toc);
              %updateTable(dispx, dispy, obj.table);
              disp('DRAWNOW');
              tic;
              drawnow;
              disp(toc);
        end

        function valid = validate(obj, handles)
            valid = true;
            if(~FileSystemParser.is_file(obj.vid_path))
                err = Error(Displacement.name(), 'Not passed a valid path on the filesystem', handles.vid_error_tag);
                valid = false;
            end
            if(~valid_color_space(obj))
                err = Error(Displacement.name(), 'Invalid Color Space', handles.vid_error_tag);
                valid = false;
            end
            if(~valid_max_displacement(obj))
                err = Error(Displacement.name(), 'Max Displacement too large', handles.vid_error_tag);
                valid = false;
            end
            if(valid)
                set(handles.vid_error_tag, 'Visible', 'Off');
            end
        end

        function valid = valid_color_space(obj)
            valid_spaces = ['rgb', 'intensity', 'none'];
            valid = false;
            for i = 1:length(valid_spaces)
                if(strcmp(obj.vid_colorspace, valid_spaces(i)))
                    valid = true;
                end
            end
        end

        function valid = valid_max_displacement(obj)
            valid = true;
            frame = vidReader.step();
            if(size(frame, 2) < obj.max_displacement || isnan(obj.max_displacement))
                valid = false;
            end 
        end
        
        function valid = valid_pixel_precision(obj)
            valid = true;
            if(isnan(obj.pixel_precision))
                valid = false;
            end
        end
        
        function boolean = paused(obj)
            boolean = (obj.pause_bool || ~obj.goodstate());
        end

        function good = goodstate(obj)
            good = true; %TODO: Implement goodstate
        end

        function pause(obj, handles)
            obj.pause_bool = true;
            set(handles.pause_vid, 'String', 'Resume Video');
        end

        function unpause(obj, handles)
            obj.pause_bool = false;
            set(handles.pause_vid, 'String', 'Pause Video');
        end

        function draw_frame(videoReader, axes)
            frame = step(videoReader);
            imshow(frame, 'Parent', axes);
            drawnow;
        end
        
        function path = get_vid_path(obj)
            path = obj.vid_path;
        end
        
        function color = get_vid_colorspace(obj)
            color = obj.vid_colorspace;    
        end
        
        function pixel_precision = get_pixel_precision(obj)
            pixel_precision = obj.pixel_precision;
        end
        
        function max_displacement = get_max_displacement(obj)
           max_displacement = obj.max_displacement;
        end
        
        function bool = check_stop(obj)
            if(~obj.valid || obj.terminated)
                bool = true;
            else
                bool = obj.vid_src.finished();
            end
        end
        
        function vid_source = get.vid_src(obj)
            vid_source = obj.vid_src;
        end
    end
    

end
