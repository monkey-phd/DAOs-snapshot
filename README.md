# Empirical Paper on DAOs

## Project Overview
This project contains the code for analyzing data related to Decentralized Autonomous Organizations (DAOs).

## Repository Structure
- `src/`: Contains the source code.
- `notebooks/`: Contains Jupyter notebooks for data processing and analysis.
- `docs/`: Contains exported files from the scripts.
- `data/`: Placeholder for small example data files.

## Data Access
Due to size constraints, the large raw data files are stored externally.

### Raw Data Files
The raw data files can be accessed from the following link:
- [data_room](https://www.dropbox.com/scl/fo/u6frpn288az2ujsnm66sh/ADhPiK4dk9Dce1aAyOPpoDA?rlkey=sloka71x5j95yu0y97e5gfgfy&dl=0)

Please download the files and place them in the `data_room/` directory before running the analysis.

## Setup Instructions
1. **Clone the repository**:
    ```sh
    git clone https://github.com/monkey-phd/DAOs-snapshot.git
    cd DAOs-snapshot/notebooks
    ```

2. **Install necessary dependencies**:
    Ensure you have Python and pip installed. Then install the required packages:
    ```sh
    pip install -r requirements.txt
    ```

3. **Download and place the raw data files**:
    Download the raw data files from the provided Dropbox link and place them in the `data_room/` directory.

4. **Run the Jupyter Notebook**:
    Start Jupyter Notebook and open the `data_processing_model.ipynb` file:
    ```sh
    jupyter notebook
    ```

5. **Run the cells in the notebook**:
    Execute the cells in the notebook to perform the data processing and analysis.

## Notes
- Ensure that the directory structure remains consistent.
- If any directory mentioned in the code does not exist, the code will create it.

## Troubleshooting
- **Missing Directories**:
    If the code cannot find a folder, it will create the folder automatically using:
    ```python
    import os

    # Directory you want to ensure exists
    directory = 'path/to/your/directory'

    # Create the directory if it doesn't exist
    if not os.path.exists(directory):
        os.makedirs(directory)
    ```

- **Dependency Issues**:
    Ensure all dependencies are installed correctly. Use `pip install -r requirements.txt` to install them.

