# Particle Engine, Peter O., 2007-11-03
# Based on version 2 by Near Fantastica, 04.01.06
# In turn based on the Particle Engine designed by PinkMan
class Particle_Engine
    def initialize(viewport = nil, map = nil)
        @map       = map || $game_map
        @viewport  = viewport
        @effect    = []
        @disposed  = false
        @firsttime = true
        @effects   = {
           # PinkMan's Effects
           "fire"         => Particle_Engine::Fire,
           "smoke"        => Particle_Engine::Smoke,
           "teleport"     => Particle_Engine::Teleport,
           "spirit"       => Particle_Engine::Spirit,
           "explosion"    => Particle_Engine::Explosion,
           "aura"         => Particle_Engine::Aura,
           # BlueScope's Effects
           "soot"         => Particle_Engine::Soot,
           "sootsmoke"    => Particle_Engine::SootSmoke,
           "rocket"       => Particle_Engine::Rocket,
           "fixteleport"  => Particle_Engine::FixedTeleport,
           "smokescreen"  => Particle_Engine::Smokescreen,
           "flare"        => Particle_Engine::Flare,
           "splash"       => Particle_Engine::Splash,
           # By Peter O.
           "starteleport" => Particle_Engine::StarTeleport,
           
           # By Zeu
           "starfield"    => Particle_Engine::CircleStarField,
        }
    end
end

def pbEventCommentInput(*args)
    parameters = []
    list = args[0].list   # Event or event page
    elements = args[1]    # Number of elements
    trigger = args[2]     # Trigger
    return nil if list == nil
    return nil unless list.is_a?(Array)
    for item in list
      next unless item.code == 108 || item.code == 408
      if item.parameters[0] == trigger
        start = list.index(item) + 1
        finish = start + elements
        for id in start...finish
          next if !list[id]
          parameters.push(list[id].parameters[0])
        end
        return parameters
      end
    end
    return nil
end

class ParticleEffect_Event
    attr_accessor :event

    def initialize(event,viewport=nil)
        @event     = event
        @viewport  = viewport
        @particles = []
        @bitmaps   = {}
        @cullOffscreen = true
        @movesupdown = false
        @movesleftright = false
    end

    def setParameters(params)
        @randomhue,@fade,
        @maxparticless,@hue,@slowdown,
        @ytop,@ybottom,@xleft,@xright,
        @xgravity,@ygravity,@xoffset,@yoffset,
        @opacityvar,@originalopacity = params
    end

    def loadBitmap(filename,hue)
        key = [filename,hue]
        bitmap = @bitmaps[key]
        if !bitmap || bitmap.disposed?
            bitmap = AnimatedBitmap.new("Graphics/Fogs/"+filename,hue).deanimate
            @bitmaps[key] = bitmap
        end
        return bitmap
    end

    def initParticles(filename,opacity,zOffset=0,blendtype=1)
        @particles = []
        @particlex = []
        @particley = []
        @opacity   = []
        @startingx = self.x + @xoffset
        @startingy = self.y + @yoffset
        @screen_x  = self.x
        @screen_y  = self.y
        @real_x    = @event.real_x
        @real_y    = @event.real_y
        @filename  = filename
        @zoffset   = zOffset
        @bmwidth   = 32
        @bmheight  = 32
        @opacityMult = 1.0
        for i in 0...@maxparticless
          @particles[i] = ParticleSprite.new(@viewport)
          @particles[i].bitmap = loadBitmap(filename, @hue) if filename
          if i==0 && @particles[i].bitmap
            @bmwidth  = @particles[i].bitmap.width
            @bmheight = @particles[i].bitmap.height
          end
          @particles[i].blend_type = blendtype
          @particles[i].z = self.z + zOffset

          resetParticle(i)
          setInitialOpacity(i)
          
          @particles[i].opacity = @opacity[i]
          @particles[i].update
        end
    end

    def setInitialOpacity(i)
        @opacity[i] = rand(opacity/4)
    end

    def x; return ScreenPosHelper.pbScreenX(@event); end
    def y; return ScreenPosHelper.pbScreenY(@event); end
    def z; return ScreenPosHelper.pbScreenZ(@event); end

    def update
        # Don't update particle events whose viewports are off screen
        if @viewport && (@viewport.rect.x >= Graphics.width || @viewport.rect.y >= Graphics.height)
            return
        end

        # Store the pre-update viewport positions
        selfX = self.x
        selfY = self.y
        selfZ = self.z

        # Calculate how to move the particles to maintain the illusion
        # of spawning in the game world
        newRealX = @event.real_x
        newRealY = @event.real_y
        @startingx = selfX + @xoffset
        @startingy = selfY + @yoffset
        @screenmovementx = (@real_x == newRealX) ? 0 : selfX - @screen_x
        @screenmovementy = (@real_y == newRealY) ? 0 : selfY - @screen_y
        @screen_x = selfX
        @screen_y = selfY
        @real_x = newRealX
        @real_y = newRealY

        # Determine if all particles are surely off screen
        # If so, skip updating this particle event
        if @opacityvar > 0 && @viewport

            # Calculate the max extent of random particle spawning
            spawningMinX = @startingx - xExtent
            spawningMaxX = @startingx + xExtent
            spawningMinY = @startingy - yExtent
            spawningMaxY = @startingy + yExtent

            # Find the maximum extent of particle position
            opac = 255.0 / @opacityvar
            minX = opac * (-@xgravity.to_f / @slowdown).floor + spawningMinX
            maxX = opac * (@xgravity.to_f / @slowdown).floor + spawningMaxX
            minY = opac * (-@ygravity.to_f / @slowdown).floor + spawningMinY
            maxY = spawningMaxY

            # Account for the size of the bitmap
            minX -= @bmwidth
            minY -= @bmheight
            maxX += @bmwidth
            maxY += @bmheight            

            if maxX < 0 || maxY < 0 || minX >= Graphics.width || minY >= Graphics.height
                return
            end
        end
        particleZ = selfZ + @zoffset

        # Update all particles
        for i in 0...@maxparticless
          updateParticle(i,particleZ)
        end
    end

    def xExtent
        return 0
    end

    def yExtent
        return 0
    end

    def updateParticle(i,particleZ)
        @particles[i].z = particleZ
        if @cullOffscreen
            if @particles[i].y <= @ytop
                resetParticle(i)
            end
            if @particles[i].x <= @xleft
                resetParticle(i)
            end
            if @particles[i].y >= @ybottom
                resetParticle(i)
            end
            if @particles[i].x >= @xright
                resetParticle(i)
            end
        end
        if @fade == 0
            if @opacity[i] <= 0
                resetOpacity(i)
                resetParticle(i)
            end
        else
            if @opacity[i] <= 0
                @opacity[i] = 250
                resetParticle(i)
            end
        end
        calcParticlePos(i)
        changeHue(i)
        changeOpacity(i)
        @particles[i].opacity = @opacity[i] * @opacityMult
        @particles[i].update
    end

    def calcParticlePos(i)
        # Calculate the effect of "gravity"
        if @movesleftright && rand(2) == 1
            xo = -@xgravity.to_f / @slowdown
        else
            xo = @xgravity.to_f / @slowdown
        end

        if @movesupdown && rand(2) == 1
            yo = -@ygravity.to_f / @slowdown
        else
            yo = @ygravity.to_f / @slowdown
        end

        # Calculate the particle position change
        @particlex[i] += xo
        @particley[i] += yo
        @particlex[i] -= @screenmovementx
        @particley[i] -= @screenmovementy

        # Actually move the particle
        @particles[i].x = @particlex[i] + @startingx + @xoffset
        @particles[i].y = @particley[i] + @startingy + @yoffset
    end

    def changeHue(i)
        if @randomhue == 1
            @hue += 0.5
            @hue = 0 if @hue >= 360
            @particles[i].bitmap = loadBitmap(@filename, @hue) if @filename
        end
    end

    def resetOpacity(i)
        @opacity[i] = @originalopacity
    end

    def changeOpacity(i)
        @opacity[i] = @opacity[i] - rand(@opacityvar)
    end

    def resetParticle(i)
        @particles[i].y = @startingy + @yoffset
        @particles[i].x = @startingx + @xoffset
        @particlex[i] = 0.0
        @particley[i] = 0.0
    end

    def dispose
        for particle in @particles
          particle.dispose
        end
        for bitmap in @bitmaps.values
          bitmap.dispose
        end
        @particles.clear
        @bitmaps.clear
    end
end

class ParticleSprite
    attr_accessor :x, :y, :z, :ox, :oy, :opacity, :blend_type, :state
    attr_reader :bitmap
  
    def initialize(viewport)
      @viewport   = viewport
      @sprite     = nil
      @x          = 0
      @y          = 0
      @z          = 0
      @ox         = 0
      @oy         = 0
      @opacity    = 255
      @bitmap     = nil
      @blend_type = 0
      @minleft    = 0
      @mintop     = 0
      @state      = 0
    end
  
    def dispose
      @sprite.dispose if @sprite
    end
  
    def bitmap=(value)
      @bitmap = value
      if value
        @minleft = -value.width
        @mintop  = -value.height
      else
        @minleft = 0
        @mintop  = 0
      end
    end
  
    def update
      w = Graphics.width
      h = Graphics.height
      if !@sprite && @x>=@minleft && @y>=@mintop && @x<w && @y<h
        @sprite = Sprite.new(@viewport)
      elsif @sprite && (@x<@minleft || @y<@mintop || @x>=w || @y>=h)
        @sprite.dispose
        @sprite = nil
      end
      if @sprite
        @sprite.x          = @x if @sprite.x!=@x
        @sprite.x          -= @ox
        @sprite.y          = @y if @sprite.y!=@y
        @sprite.y          -= @oy
        @sprite.z          = @z if @sprite.z!=@z
        @sprite.opacity    = @opacity if @sprite.opacity!=@opacity
        @sprite.blend_type = @blend_type if @sprite.blend_type!=@blend_type
        @sprite.bitmap     = @bitmap if @sprite.bitmap!=@bitmap
      end
    end
  end

class Particle_Engine::CircleStarField < ParticleEffect_Event
    def initialize(event,viewport)
        super
        setParameters([
            0, # Random hue
            0, # fade
            50, # max particles
            -80, # hue
            5, # slowdown
            -Graphics.height, # ytop
            Graphics.height, # ybottom
            0, # xleft
            Graphics.width, # xright
            0, # xgravity
            0, # ygravity
            0, # xoffset
            0, # yoffset
            3, # opacity var
            5 # original opacity
            ])
        @opacityMult = 0.6
        @huerange = 80
        @cullOffscreen = false
        @movesleftright = true
        @movesupdown = true
        @radius = 350
        @rad2 = @radius * @radius

        initParticles("particle",100)
    end

    def resetParticle(i)
        randomRad = Math.sqrt(rand(@rad2))
        randomAngle = rand(360)
        xRand = Math.cos(randomAngle) * randomRad
        yRand = Math.sin(randomAngle) * randomRad
        @particles[i].x = @startingx + @xoffset + xRand
        @particles[i].y = @startingy + @yoffset + yRand
        @particlex[i] = xRand
        @particley[i] = yRand
        @particles[i].state = 0

        hue = @hue + rand(@huerange) - @huerange / 2
        hue -= 360 if @hue >= 360
        hue += 360 if @hue <= 0

        @particles[i].bitmap = loadBitmap(@filename, hue)
    end

    def resetOpacity(i)
        @opacity[i] = 1
        @particles[i].state = 0
    end

    def setInitialOpacity(i)
        @opacity[i] = rand(249)
    end

    def changeOpacity(i)
        if @particles[i].state == 0
            @opacity[i] += rand(3)
            if @opacity[i] >= 250
                @particles[i].state = 1
            end
        else
            @opacity[i] -= rand(3)
        end
    end

    def xExtent
        return @radius
    end

    def yExtent
        return @radius
    end
end