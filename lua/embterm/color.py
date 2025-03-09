def highlight_red(msg):
    """
    Highlights the input message in red color.

    Args:
        msg (str): The message to be highlighted.

    Returns:
        str: The highlighted message.
    """
    # ANSI escape code for red color
    return f"\u001b[41m\u001b[30m{msg}\033[0m"


def highlight_green(msg):
    """
    Highlights the input message in green color.

    Args:
        msg (str): The message to be highlighted.

    Returns:
        str: The highlighted message.
    """
    # ANSI escape code for green color
    return f"\u001b[42m\u001b[30m{msg}\033[0m"


def highlight_yellow(msg):
    """
    Highlights the input message in yellow color.

    Args:
        msg (str): The message to be highlighted.

    Returns:
        str: The highlighted message.
    """
    # ANSI escape code for yellow color
    return f"\u001b[43m\u001b[30m{msg}\033[0m"


def text_red(msg):
    """
    Highlights the input message in red color without resetting the color.

    Args:
        msg (str): The message to be highlighted.

    Returns:
        str: The highlighted message.
    """
    # ANSI escape code for red color
    return f"\u001b[31m{msg}\033[0m"


def text_green(msg):
    """
    Highlights the input message in green color without resetting the color.

    Args:
        msg (str): The message to be highlighted.

    Returns:
        str: The highlighted message.
    """
    # ANSI escape code for green color
    return f"\u001b[32m{msg}\033[0m"


def text_yellow(msg):
    """
    Highlights the input message in yellow color without resetting the color.

    Args:
        msg (str): The message to be highlighted.

    Returns:
        str: The highlighted message.
    """
    # ANSI escape code for yellow color
    return f"\u001b[33m{msg}\033[0m"
