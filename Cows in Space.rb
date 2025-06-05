require 'ruby2d'

ASSETS_PATH = File.expand_path('assets', __dir__)

set title: 'Cows in Space'
set width: 1280
set height: 720


class Star
  def initialize
    @y_velocity = rand(-5..0)
    @shape = Circle.new(
      x: rand(Window.width),
      y: rand(Window.height),
      radius: rand(1..2),
      color: 'random',
      z: -2
    )
  end

  def move
    @shape.y = (@shape.y + @y_velocity) % Window.height
  end
end

class Player
  WIDTH = 32 * 3
  HEIGHT = 46 * 3
  ROTATE_SPEED = 5
  VELOCITY_INCREASE_SPEED = 0.2
  MAX_VELOCITY = 10
  SLOW_DOWN_RATE = 0.99

  attr_reader :image, :x, :y, :speed, :fire_rate, :sprite, :projectiles
  attr_accessor :lives

  def initialize(image, x, y, speed, fire_rate)
    @x_velocity = 0
    @y_velocity = 0
    @image = image
    @x = x
    @y = y
    @speed = speed
    @fire_rate = fire_rate
    @projectiles = []
    @last_projectile_fired_frame = 0
    @sprite = Sprite.new(
      image,
      clip_width: 32,
      width: WIDTH,
      height: HEIGHT,
      x: x,
      y: y,
      rotate: 180,
      animations: {
        moving_slow: 1..2,
        moving_fast: 3..4
      }
    )
    @lives = 3 # Vidas do jogador
  end

  def animate_slow
    @sprite.play(animation: :moving_slow, loop: true)
  end

  def animate_fast
    @sprite.play(animation: :moving_fast, loop: true)
  end

  def rotate(direction)
    case direction
    when :left
      @sprite.rotate -= ROTATE_SPEED
    when :right
      @sprite.rotate += ROTATE_SPEED
    end
  end

  def accelerate(direction)
    animate_fast

    x_component = Math.sin(@sprite.rotate * Math::PI / 180) * VELOCITY_INCREASE_SPEED * (@speed / 100.0)
    y_component = Math.cos(@sprite.rotate * Math::PI / 180) * VELOCITY_INCREASE_SPEED * (@speed / 100.0)

    case direction
    when :forwards
      @x_velocity += x_component
      @y_velocity -= y_component
    when :backwards
      @x_velocity -= x_component
      @y_velocity += y_component
    end

    total_velocity = @x_velocity.abs + @y_velocity.abs

    if total_velocity > MAX_VELOCITY
      @x_velocity = @x_velocity * (MAX_VELOCITY / total_velocity)
      @y_velocity = @y_velocity * (MAX_VELOCITY / total_velocity)
    end
  end

  def move
    @sprite.x += @x_velocity
    @sprite.y += @y_velocity

    # Wrap around screen
    if @sprite.x > Window.width + @sprite.width
      @sprite.x = -@sprite.width
    elsif @sprite.x < -@sprite.width
      @sprite.x = Window.width + @sprite.width
    end

    if @sprite.y > Window.height + @sprite.height
      @sprite.y = -@sprite.height
    elsif @sprite.y < -@sprite.height
      @sprite.y = Window.height + @sprite.height
    end
  end

  def slow_down
    @x_velocity *= SLOW_DOWN_RATE
    @y_velocity *= SLOW_DOWN_RATE
  end

  def stop_accelerating
    animate_slow
  end

  def fire_projectile
    if @last_projectile_fired_frame + 25 - (@fire_rate / 10) < Window.frames
      x_component = Math.sin(@sprite.rotate * Math::PI / 180)
      y_component = -Math.cos(@sprite.rotate * Math::PI / 180)

      proj_start_x = @sprite.x + (@sprite.width * 0.5) + (x_component * @sprite.width * 0.6)
      proj_start_y = @sprite.y + (@sprite.height * 0.5) + (y_component * @sprite.height * 0.6)

      @projectiles.push(Projectile.new(proj_start_x, proj_start_y, @sprite.rotate))
      @projectiles = @projectiles.last(20)
      @last_projectile_fired_frame = Window.frames
    end
  end

  def hit_by_asteroid # MÉTODO RENOMEADO
    @lives -= 1
  end

  def remove
    @sprite.remove
  end
end

class PlayerSelectScreen

  def initialize
    @stars = Array.new(400).map { Star.new }

    title_text = Text.new('Cows in Space', size: 72, y: 40, font: File.join(ASSETS_PATH, 'fonts', 'PixelifySans-Regular.ttf'))
    title_text.x = (Window.width - title_text.width) / 2

    player_select_text = Text.new('Selecione seu jogador: ', size: 32, y: 130, font: File.join(ASSETS_PATH, 'fonts', 'PixelifySans-Regular.ttf'))
    player_select_text.x = (Window.width - player_select_text.width) / 2


    @player_prototypes = [
      {image: File.join(ASSETS_PATH, 'images', 'jogador 1.png'), x: Window.width * (1/4.0) - Player::WIDTH / 2, y: 240, speed: 80, fire_rate: 80},
      {image: File.join(ASSETS_PATH, 'images', 'jogador 2.png'), x: Window.width * (2/4.0) - Player::WIDTH / 2, y: 240, speed: 100, fire_rate: 60},
      {image: File.join(ASSETS_PATH, 'images', 'jogador 3.png'), x: Window.width * (3/4.0) - Player::WIDTH / 2, y: 240, speed: 60, fire_rate: 100},
    ]
 
    @display_players = @player_prototypes.map do |p_data|
      Player.new(p_data[:image], p_data[:x], p_data[:y], p_data[:speed], p_data[:fire_rate])
    end


    @selected_player_index = 1

    animate_players
    add_player_masks
    set_player_stat_text
  end

  def update
    if Window.frames % 2 == 0
      @stars.each { |star| star.move }
    end
  end

  def animate_players
    @display_players.each_with_index do |player, index|
      if index == @selected_player_index
        player.animate_fast
      else
        player.animate_slow
      end
    end
  end

  def move(direction)
    if direction == :left
      @selected_player_index = (@selected_player_index - 1) % @display_players.length
    else
      @selected_player_index = (@selected_player_index + 1) % @display_players.length
    end

    animate_players
    add_player_masks
    set_player_stat_text
  end

  def add_player_masks
    @player_masks && @player_masks.each { |mask| mask.remove }

    @player_masks = @display_players.each_with_index.map do |player, index|
      if index == @selected_player_index
        color = [0.2, 0.2, 0.2, 0.6]
        z = -1
      else
        color = [0.0, 0.0, 0.0, 0.6]
        z = 2
      end

      Circle.new(
        radius: 100,
        sectors: 32,
        x: player.sprite.x + (Player::WIDTH / 2), # Usa player.sprite.x
        y: player.sprite.y + (Player::HEIGHT / 2),# Usa player.sprite.y
        color: color,
        z: z
      )
    end
  end

  def set_player_stat_text
    @player_stat_texts && @player_stat_texts.each { |text| text.remove }

    @player_stat_texts = []
    @display_players.each_with_index do |player, index| # Usa @display_players
      if index == @selected_player_index
        color = Color.new([1,1,1,1])
      else
        color = Color.new([0.3,0.3,0.3,1])
      end

      speed_text = Text.new("Velocidade - #{player.speed}%", size: 20, y: player.sprite.y + 200, color: color, font: File.join(ASSETS_PATH, 'fonts', 'PixelifySans-Regular.ttf'))
      speed_text.x = player.sprite.x + ((Player::WIDTH - speed_text.width)/2)

      fire_rate_text = Text.new("Quantia de disparo - #{player.fire_rate}%", size: 20, y: player.sprite.y + 220, color: color, font: File.join(ASSETS_PATH, 'fonts', 'PixelifySans-Regular.ttf'))
      fire_rate_text.x = player.sprite.x + ((Player::WIDTH - fire_rate_text.width)/2)

      @player_stat_texts.push(speed_text)
      @player_stat_texts.push(fire_rate_text)
    end
  end

  def selected_player_data # Retorna os dados do protótipo
    @player_prototypes[@selected_player_index]
  end

  def clear_screen

    @stars.each { |s| s.instance_variable_get(:@shape).remove }
    @display_players.each { |p| p.sprite.remove }
    @player_masks&.each { |mask| mask.remove }
    @player_stat_texts&.each { |text| text.remove }

  end
end

class Asteroid
  WIDTH = 20 * 4
  HEIGHT = 17 * 4
  SPEEDS = (1..4).to_a
  ROTATIONS = (-2..2).to_a

  attr_reader :sprite

  def initialize
    scale = 0.5 + (rand * 1.5)
    speed = SPEEDS.sample
    @rotation_speed = ROTATIONS.sample # Renomeado para evitar conflito com sprite.rotate
    @sprite = Sprite.new(
      File.join(ASSETS_PATH, 'images', 'Idle.png'),
      x:rand(Window.width),
      y: rand(-HEIGHT..0), # Começa um pouco acima da tela
      width: WIDTH * scale,
      height: HEIGHT * scale,
      rotate: rand(360)
    )

    # Movimento inicial aleatório, mas geralmente para baixo
    angle_rad = (@sprite.rotate + 90 + rand(-30..30)) * Math::PI / 180 # Variação para baixo
    @x_velocity = Math.cos(angle_rad) * speed
    @y_velocity = Math.sin(angle_rad) * speed
  end

  def move
    @sprite.rotate += @rotation_speed
    @sprite.x += @x_velocity
    @sprite.y += @y_velocity



    if @sprite.x > Window.width + @sprite.width
      @sprite.x = -@sprite.width
    elsif @sprite.x < -@sprite.width
      @sprite.x = Window.width + @sprite.width
    end

    if @sprite.y > Window.height + @sprite.height
      # Reposiciona no topo se sair por baixo
      @sprite.y = -@sprite.height
      @sprite.x = rand(Window.width)
    elsif @sprite.y < -@sprite.height && @y_velocity < 0 # Se sair por cima (menos provável com spawn no topo)
      @sprite.y = Window.height + @sprite.height
    end
  end

  def remove
    @sprite.remove
  end

  def off_screen_completely? # Para possível limpeza se não fizer wrap around
    @sprite.y > Window.height + @sprite.height ||
      @sprite.y < -@sprite.height - 100 || # 100 é uma margem
      @sprite.x > Window.width + @sprite.width ||
      @sprite.x < -@sprite.width
  end
end

class GameScreen
  MAX_ASTEROIDS = 8 # Número de asteroides na tela
  ASTEROID_SPAWN_INTERVAL = 60 # A cada X frames, tenta adicionar um novo asteroide

  attr_reader :game_over

  def initialize(player_data) # Recebe os dados do jogador selecionado
    @stars = Array.new(300).map { Star.new }
    @player = Player.new(
      player_data[:image],
      Window.width / 2 - Player::WIDTH / 2,       # Posição inicial X no jogo
      Window.height - Player::HEIGHT - 50,      # Posição inicial Y no jogo
      player_data[:speed],
      player_data[:fire_rate]
    )
    @player.animate_slow
    @asteroids = []
    # Inicializa alguns asteroides para começar
    MAX_ASTEROIDS.times { @asteroids.push(Asteroid.new) }


    @game_over = false
    @game_over_message = nil
    @restart_message = nil

    @lives_text = Text.new(
      "Vidas: #{@player.lives}",
      x: 10, y: 10, size: 20,
      font: File.join(ASSETS_PATH, 'fonts', 'PixelifySans-Regular.ttf'),
      color: 'white',
      z: 10
    )
    @score = 0
    @score_text = Text.new(
      "Score: #{@score}",
      x: Window.width - 150, y: 10, size: 20,
      font: File.join(ASSETS_PATH, 'fonts', 'PixelifySans-Regular.ttf'),
      color: 'white',
      z: 10
    )
  end

  def update
    if @game_over
      return
    end

    if Window.frames % 2 == 0
      @stars.each { |star| star.move }
    end

    # Gerenciar Asteroides (spawn e remoção se necessário)
    if Window.frames % ASTEROID_SPAWN_INTERVAL == 0 && @asteroids.size < MAX_ASTEROIDS
      @asteroids.push(Asteroid.new)
    end



    @asteroids.each { |asteroid| asteroid.move }
    @player.projectiles.each(&:move) # Movimenta projéteis

    @player.move
    @player.slow_down

    check_collisions

    @lives_text.text = "Vidas: #{@player.lives}"
    @score_text.text = "Score: #{@score}"

    check_game_over_condition
  end

  def check_collisions
    player_sprite = @player.sprite

    # Colisão: Projéteis vs Asteroides
    @player.projectiles.dup.each do |projectile|
      @asteroids.dup.each do |asteroid|
        # Checagem de colisão AABB (Axis-Aligned Bounding Box)
        if projectile.image.x < asteroid.sprite.x + asteroid.sprite.width &&
          projectile.image.x + projectile.image.width > asteroid.sprite.x &&
          projectile.image.y < asteroid.sprite.y + asteroid.sprite.height &&
          projectile.image.y + projectile.image.height > asteroid.sprite.y

          projectile.remove
          @player.projectiles.delete(projectile)

          asteroid.remove
          @asteroids.delete(asteroid)
          @score += 100


          @asteroids.push(Asteroid.new) if @asteroids.size < MAX_ASTEROIDS
          break
        end
      end
    end

    # Colisão: Asteroides vs Nave
    @asteroids.dup.each do |asteroid|
      if player_sprite.x < asteroid.sprite.x + asteroid.sprite.width &&
        player_sprite.x + player_sprite.width > asteroid.sprite.x &&
        player_sprite.y < asteroid.sprite.y + asteroid.sprite.height &&
        player_sprite.y + player_sprite.height > asteroid.sprite.y

        asteroid.remove
        @asteroids.delete(asteroid)
        @player.hit_by_asteroid
        @score -= 50
        @score = 0 if @score < 0



        @asteroids.push(Asteroid.new) if @asteroids.size < MAX_ASTEROIDS

      end
    end
  end

  def check_game_over_condition
    if @player.lives <= 0 && !@game_over
      @game_over = true
      show_game_over_screen
    end
  end

  def show_game_over_screen

    @player.remove
    @asteroids.each(&:remove)
    @player.projectiles.each(&:remove)
    @player.projectiles.clear
    @asteroids.clear
    @lives_text.remove
    @score_text.remove # Remove texto de score da tela de jogo


    final_score_text = Text.new(
      "Score Final: #{@score}",
      x: (Window.width - 250) / 2, y: (Window.height / 2) - 100, # Ajusta posição
      size: 40, color: 'yellow',
      font: File.join(ASSETS_PATH, 'fonts', 'PixelifySans-Regular.ttf'),
      z: 20
    )
    final_score_text.x = (Window.width - final_score_text.width) / 2 # Centraliza

    @game_over_message = Text.new(
      'GAME OVER',
      x: (Window.width - 300) / 2, y: (Window.height / 2) - 50,
      size: 72, color: 'red',
      font: File.join(ASSETS_PATH, 'fonts', 'PixelifySans-Regular.ttf'),
      z: 20
    )
    @game_over_message.x = (Window.width - @game_over_message.width) / 2 # Centraliza

    @restart_message = Text.new(
      'Pressione ENTER para voltar ao Menu Principal',
      x: (Window.width - 600) / 2, y: (Window.height / 2) + 50,
      size: 30, color: 'white',
      font: File.join(ASSETS_PATH, 'fonts', 'PixelifySans-Regular.ttf'),
      z: 20
    )
    @restart_message.x = (Window.width - @restart_message.width) / 2 # Centraliza


    @final_score_text_obj = final_score_text
  end

  def clear_game_over_screen
    @final_score_text_obj&.remove
    @game_over_message&.remove
    @restart_message&.remove
    @stars.each { |s| s.instance_variable_get(:@shape).remove }
  end

  def rotate_player(direction)
    @player.rotate(direction) unless @game_over
  end

  def accelerate_player(direction)
    @player.accelerate(direction) unless @game_over
  end

  def stop_accelerating_player
    @player.stop_accelerating unless @game_over
  end

  def player_fire_projectile
    @player.fire_projectile unless @game_over
  end
end

class Projectile
  WIDTH = 50 * 0.6
  HEIGHT = 42 * 0.6
  SPEED = 12

  attr_reader :image

  def initialize(x, y, rotate)
    @image = Sprite.new(
      File.join(ASSETS_PATH, 'images', 'Pow Pow Tei Tei 2.0.png'),
      x: x - WIDTH / 2,
      y: y - HEIGHT / 2,
      width: WIDTH,
      height: HEIGHT,
      rotate: rotate,
      z: 1
    )
    @x_velocity = Math.sin(@image.rotate * Math::PI / 180) * SPEED
    @y_velocity = -Math.cos(@image.rotate * Math::PI / 180) * SPEED
    @removed = false # Flag para indicar se foi removido
  end

  def move
    return if @removed
    @image.x += @x_velocity
    @image.y += @y_velocity
  end

  def remove
    unless @removed
      @image.remove
      @removed = true
    end
  end

  def off_screen?
    return @removed || # Se já foi removido, considera off_screen para limpeza
      (@image.y < -@image.height || @image.y > Window.height ||
        @image.x < -@image.width || @image.x > Window.width)
  end

  def removed?
    @removed
  end
end

current_screen = PlayerSelectScreen.new

update do
  if current_screen.is_a?(GameScreen) && !current_screen.game_over

    current_screen.instance_variable_get(:@player).projectiles.reject! do |p|
      p.removed? || p.off_screen? ? (p.remove unless p.removed?; true) : false
    end
  end
  current_screen.update
end

on :key_down do |event|
  case current_screen
  when PlayerSelectScreen
    case event.key
    when 'left'
      current_screen.move(:left)
    when 'right'
      current_screen.move(:right)
    when 'return'
      player_data = current_screen.selected_player_data
      current_screen.clear_screen # Limpa elementos visuais da tela de seleção
      Window.clear
      current_screen = GameScreen.new(player_data)
    end
  when GameScreen
    if current_screen.game_over && event.key == 'return'
      current_screen.clear_game_over_screen
      Window.clear
      current_screen = PlayerSelectScreen.new
    end
  end
end

on :key_held do |event|
  case current_screen
  when GameScreen
    unless current_screen.game_over
      case event.key
      when 'up'
        current_screen.accelerate_player(:forwards)
      when 'down'
        current_screen.accelerate_player(:backwards)
      when 'left'
        current_screen.rotate_player(:left)
      when 'right'
        current_screen.rotate_player(:right)
      when 'space'
        current_screen.player_fire_projectile
      end
    end
  end
end

on :key_up do |event|
  case current_screen
  when GameScreen
    unless current_screen.game_over
      case event.key
      when 'up', 'down'
        current_screen.stop_accelerating_player
      end
    end
  end
end

show
