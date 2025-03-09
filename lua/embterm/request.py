import requests
import json

enabled = True  # Flag to track API enablement


def disable():
    """
    Disables the API.

    Returns:
        None
    """
    global enabled
    enabled = False


def enable():
    """
    Enables the API.

    Returns:
        None
    """
    global enabled
    enabled = True


def is_enabled():
    """
    Checks if the API is enabled.

    Returns:
        bool: True if enabled, False otherwise.
    """
    global enabled
    return enabled


def JSON(data):
    """
    Converts data to a JSON string with indentation.

    Args:
        data (any): Data to be converted.

    Returns:
        str or None: JSON string or None on error.
    """
    try:
        return json.dumps(data, indent=4)
    except Exception as e:
        print(f"Error: {e}")
        return None


def POST(url, data, callback, error=None, on_finish=None):
    response = requests.post(url, json=data, stream=True)
    try:
        for line in response.iter_lines():
            callback(DICT(line))
    except KeyboardInterrupt:
        if error is None:
            pass
        else:
            error()
    if on_finish is None:
        pass
    else:
        on_finish()


def DICT(json_data):
    try:
        return json.loads(json_data)
    except Exception as e:
        print(f"Error: {e}")
        return None
