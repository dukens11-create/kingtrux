# KINGTRUX - Truck GPS Application

## Features
- GPS tracking using Google Maps API
- Advanced route planning with HERE Routing
- Integration with OpenStreetMap for Points of Interest (POIs)
- Real-time weather updates within the application

## Setup Instructions
1. Clone the repository:  
   `git clone https://github.com/dukens11-create/kingtrux.git`
2. Navigate to the project directory:  
   `cd kingtrux`
3. Install required dependencies:  
   `npm install`
4. Create a `.env` file and add your Google Maps and HERE Routing API keys.
5. Start the application:  
   `npm start`

## Usage Guide
- Open the application in your web browser.
- Use the map interface to input your current location and destination.
- Adjust route parameters as necessary (e.g., avoid tolls, optimize for distance).
- Click 'Get Route' to receive your optimized route.
- Monitor your current location and estimated time of arrival (ETA).

## File Structure
```
kingtrux/
├── src/
│   ├── components/    # React components
│   ├── services/      # API service functions
│   └── App.js         # Main application file
├── public/            # Static files
├── .env               # Environment variables
├── package.json       # Project metadata and dependencies
└── README.md          # Documentation
```

## Technical Details
- **Framework**: ReactJS for the front end.
- **APIs Used**:
  - Google Maps API for mapping functionality.
  - HERE Routing API for finding optimal routes.
  - OpenStreetMap for accessing POIs.
  - Weather API for real-time weather data.
- **Deployment**: The application can be deployed on any static web hosting service.

## Contribution
Contributions are welcome! Please submit pull requests for any improvements or features.

## License
This project is licensed under the MIT License.