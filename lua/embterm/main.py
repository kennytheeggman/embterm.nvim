from request import POST, disable, enable
from color import highlight_green, highlight_red, highlight_yellow, text_green, text_red, text_yellow
import pyperclip
import sys
import os
# import threading


# Initialize an empty string variable 'clip' to store user input or clipboard content.
clip = ""

# Initialize an empty string variable 'answer' to store the final response from the AI.
answer = ""

# Initialize a list of dictionaries with a single entry, containing role and content keys, 
# used for storing messages or responses in the chat interface.
messages = [{"role": "assistant", "content": ""}]

# Set a boolean flag 'quick_accept' to True by default, allowing quick acceptance of user input.
quick_accept = False

# Initialize a boolean flag 'code_block_line' to False, indicating that code blocks are not currently active.
code_block_line = False


def user_message(msg):
    """
    Records a message from a user.

    Args:
        msg (str): The message to be recorded.
    """
    # Append the message to the list of messages
    global messages
    messages.append({
        "role": "user",
        "content": msg
    })


def assistant_message(msg):
    """
    Sends a message from an assistant role.

    Args:
        msg (str): The message to be sent.
    """
    # Append the message to the list of messages
    global messages
    messages.append({
        "role": "assistant",
        "content": msg
    })


def chat(msg):
    """
    Starts a new chat session with the LLaMA-Coder model.

    Args:
        msg (str): The initial message to send to the model.
    """

    global answer
    global file_path
    answer = ""
    with open(file_path, "w") as file:
        file.write(answer)

    # Call the user's message function to get their input text
    user_message(msg)

    # Define the body of the POST request with the required parameters
    body = {
        "model": "llama-coder",  # The LLaMA-Coder model for generating text
        "messages": messages,  # The input text to generate a response for
        "stream": True  # Enable streaming mode for handling the response
    }

    # Define a callback function to handle the end of the chat session
    def end_chat():
        """
        Sends the last message from the user and starts a new chat loop.
        """

        # Send the last message from the user to the model
        assistant_message(answer)

        # Start a new chat loop
        chat_loop()

    enable()
    POST("http://localhost:11434/api/chat", body, chat_stream_callback)
    # new = run_diff(answer, clip)
    # if new is None:
    #    pass
    # else:
    #    answer = new
    chat_loop()


def generate():
    """
    Initiates the text generation process using the LLaMA-Coder model.

    The function sets up a request to the API endpoint for generating text and
    defines callbacks for handling the response.
    """

    global answer
    global clip
    global file_path
    # Initialize an empty string to store the generated answer
    answer = ""
    with open(file_path, "w") as file:
        file.write(answer)

    body = {
        "model": "llama-coder",  # The LLaMA-Coder model for generating text
        "prompt": clip,  # The input text to generate a response for
        "stream": True  # Enable streaming mode for handling the response
    }

    print(text_yellow("Generating"))

    enable()
    POST("http://localhost:11434/api/generate", body, generate_stream_callback)
    # new = run_diff(answer, clip)
    # if new is None:
    #     pass
    # else:
    #     answer = new
    chat_loop()


def chat_loop():
    """
    Main loop for the chat application

    Continuously prompts the user for input, processes commands, and handles chat messages.
    """

    # Disable any console output to clean up the interface
    disable()

    # Print a blank line to separate from previous output

    # Declare global variables used within this function
    global messages
    global answer
    global clip

    while True:
        # Prompt the user for input and store it in 'inp'
        inp = input(">>> ")
        with open(file_path, "r") as f:
            answer = f.read()

        # If the user types '/regen', call the generate function
        if inp == "/regen":
            print(text_yellow("Regenerate answer"))
            generate()

        # If the user types '/clear', reset the messages list to its first element
        elif inp == "/clear":
            print(text_yellow("Cleared context"))
            messages = [messages[0]]
            answer = messages[0]["content"]

        # Handle /accept command, copy the current answer to the clipboard and exit the program
        elif inp == "/accept":
            print(highlight_green("Accept answer"))
            pyperclip.copy(answer)  # Copy the current answer to the clipboard
            os.remove(file_path)
            exit(0)

        # If the user types '/bye', exit the loop
        elif inp == "/reject":
            print(highlight_red("Reject answer"))
            os.remove(file_path)
            exit(0)

        elif inp == "":
            continue

        # For any other input, call the chat function with the input as an argument
        else:
            chat(inp)


def chat_stream_callback(json):
    """
    Handles the callback for a chat stream.

    Args:
        json (dict): The JSON object containing the message content.
    """
    # Check if the 'message' key exists in the JSON object
    if "message" not in json:
        print(text_red("Invalid JSON format. Expected 'message' key."))
        return

    # Extract the message content from the JSON object
    global code_block_line
    response = json["message"]["content"]
    if "\n" in response:
        code_block_line = False
    elif "```" in response:
        code_block_line = True
    if code_block_line:
        return

    # Print the response to the console, appending a newline character for better readability
    # print(response, end="")

    # Update the last chat message with the new response
    # Ensure the response is appended to the global answer variable
    global answer
    answer += response

    # Define global variables for file path and content boundaries
    global file_path
    global parent_content_start
    global parent_content_end

    # Attempt to open the file in write mode
    with open(file_path, "w") as file:
        # Write the updated content to the file
        file.write(parent_content_start + "\n" + answer + "\n" + parent_content_end)

    # Flush the stdout buffer to ensure immediate display of the output
    sys.stdout.flush()


def generate_stream_callback(line):
    """
    Generate a stream callback to handle the response from the input.

    Args:
        line (dict): A dictionary containing the response.
            - response (str): The actual response from the input.

    Returns:
        None
    """

    # Extract the response from the input line
    global code_block_line
    response = line["response"]
    if "\n" in response:
        code_block_line = False
    elif "```" in response:
        code_block_line = True
    if code_block_line:
        return

    # Print the response to the standard output, without a newline character
        # print(response, end="")

    # Update the global answer variable with the current response
    global answer
    answer += response
    global file_path
    global parent_content_start
    global parent_content_end
    with open(file_path, "w") as file:
        file.write(parent_content_start + "\n" + answer + "\n" + parent_content_end)
        # file.write(answer)

    # Flush the standard output buffer to ensure immediate display of the response
    sys.stdout.flush()


file_path = ".tmp.diff"
parent_content_start = ""
parent_content_end = ""

if __name__ == "__main__":
    lines = [0, 0]
    parent_content = None
    parent_file = None
    if (len(sys.argv) > 1):
        file_path = sys.argv[1]
        parent_file = sys.argv[2]
        lines[0] = int(sys.argv[3])
        lines[1] = int(sys.argv[4])
        with open(parent_file, "r") as file:
            parent_content = file.read().split("\n")
            for i in range(lines[0]):
                parent_content_start += parent_content[i] + "\n"
            for i in range(lines[1] + 1, len(parent_content)):
                parent_content_end += parent_content[i] + "\n"
        # print(parent_content_start, parent_content_end)
        # parent_content_start = ""
        # parent_content_end = ""
    clip = pyperclip.paste()
    generate()

