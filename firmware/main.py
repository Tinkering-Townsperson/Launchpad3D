logging = False
datalogger.set_column_titles("acc_x", "acc_y", "acc_z", "mag", "sound", "temp")

def on_button_pressed_a():
    global logging

    logging = not logging
    if logging:
        basic.show_icon(IconNames.YES)
    else:
        basic.show_icon(IconNames.NO)
input.on_button_pressed(Button.A, on_button_pressed_a)


def on_button_pressed_ab():
    datalogger.delete_log()
    basic.show_icon(IconNames.CHESSBOARD)
input.on_button_pressed(Button.AB, on_button_pressed_ab)

def on_every_interval():
    if not logging:
        return
    datalogger.log(
        datalogger.create_cv("acc_x", input.acceleration(Dimension.X)),
        datalogger.create_cv("acc_y", input.acceleration(Dimension.Y)),
        datalogger.create_cv("acc_z", input.acceleration(Dimension.Z)),
        datalogger.create_cv("mag", input.magnetic_force(Dimension.STRENGTH)),
        datalogger.create_cv("sound", input.sound_level()),
        datalogger.create_cv("temp", input.temperature())
    )
loops.every_interval(50, on_every_interval)

def on_log_full():
    basic.show_icon(IconNames.SKULL)
datalogger.on_log_full(on_log_full)
