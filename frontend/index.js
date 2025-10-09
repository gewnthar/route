document.addEventListener('DOMContentLoaded', () => {
    const findRoutesBtn = document.getElementById('find-routes-btn');
    const originInput = document.getElementById('origin');
    const destinationInput = document.getElementById('destination');
    const routesResultsArea = document.getElementById('routes-results-area');
    const currentYearSpan = document.getElementById('current-year');
    const API_BASE_URL = '/api';

    if (currentYearSpan) {
        currentYearSpan.textContent = new Date().getFullYear();
    }

    const displayResults = (areaElement, data, type) => {
        areaElement.innerHTML = ''; // Clear previous results
        if (type === 'error') {
            areaElement.innerHTML = `<p class="error-message">${data}</p>`;
        } else if (type === 'loading') {
            areaElement.innerHTML = `<p class="loading-message">${data}</p>`;
        } else if (type === 'routes' && Array.isArray(data)) {
            if (data.length === 0) {
                areaElement.innerHTML = '<p class="placeholder">No routes found matching your criteria.</p>';
                return;
            }

            const routeGroups = {
                preferred: [],
                cdrNoCoord: [],
                cdrCoord: [],
                other: [],
            };

            data.forEach(route => {
                if (route.Source?.includes("Preferred")) {
                    routeGroups.preferred.push(route);
                } else if (route.Source?.includes("No Coord")) {
                    routeGroups.cdrNoCoord.push(route);
                } else if (route.Source?.includes("CDR")) {
                    routeGroups.cdrCoord.push(route);
                } else {
                    routeGroups.other.push(route);
                }
            });

            const createTableHTML = (routes, title) => {
                if (routes.length === 0) return '';
                let table = `<h3>${title}</h3><table><thead><tr><th>Route</th><th>Type</th><th>Notes</th></tr></thead><tbody>`;
                routes.forEach(r => {
                    const routeString = r.RouteString || 'N/A';
                    const sourceType = r.Source || 'N/A';
                    const notes = r.Restrictions || r.Justification || '';
                    table += `<tr><td>${routeString}</td><td>${sourceType}</td><td>${notes}</td></tr>`;
                });
                table += '</tbody></table>';
                return table;
            };

            let finalHTML = createTableHTML(routeGroups.preferred, 'Preferred Routes');
            finalHTML += createTableHTML(routeGroups.cdrNoCoord, 'CDRs (No Coordination)');
            finalHTML += createTableHTML(routeGroups.cdrCoord, 'CDRs (Coordination Required)');
            finalHTML += createTableHTML(routeGroups.other, 'Other');
            
            areaElement.innerHTML = finalHTML;
        }
    };

    findRoutesBtn.addEventListener('click', async () => {
        const origin = originInput.value.trim().toUpperCase();
        const destination = destinationInput.value.trim().toUpperCase();

        if (!origin || !destination) {
            displayResults(routesResultsArea, 'Origin and Destination are required.', 'error');
            return;
        }
        
        displayResults(routesResultsArea, 'Finding routes...', 'loading');

        try {
            // Note: In a real app, this API endpoint would be '/api/routes/find'
            // We are mocking a response for now.
            // const response = await fetch(`${API_BASE_URL}/routes/find`, {
            //     method: 'POST',
            //     headers: { 'Content-Type': 'application/json' },
            //     body: JSON.stringify({ origin, destination })
            // });

            // MOCK RESPONSE FOR DEMONSTRATION
            await new Promise(resolve => setTimeout(resolve, 1000)); // Simulate network delay
            const mockData = [
                { RouteString: "JFK.COATE.TEB", Source: "Preferred Route", Restrictions: "TURBOJETS ONLY" },
                { RouteString: "JFK.DPK.SWL.BOS", Source: "CDR (No Coord)" },
                { RouteString: "JFK.GAYEL.PUT.MIA", Source: "CDR (Coord Req)", Justification: "AVOID ZNY" }
            ];
            const response = { ok: true, json: () => Promise.resolve(mockData) };
            // END MOCK

            if (!response.ok) {
                const errData = await response.json().catch(() => ({ error: 'An unknown error occurred.' }));
                throw new Error(errData.error || `HTTP error! status: ${response.status}`);
            }

            const data = await response.json();
            displayResults(routesResultsArea, data, 'routes');

        } catch (error) {
            console.error('Error finding routes:', error);
            displayResults(routesResultsArea, `Error: ${error.message}`, 'error');
        }
    });
});
