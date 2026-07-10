#!/usr/bin/env python3
"""
Company Lookup E2E Test - Python Implementation

This test program demonstrates all 8 sovdev-logger API functions in a realistic
batch processing scenario that queries the Norwegian company registry (BRREG).

Expected Output: 17 log entries
- 1 application start
- 1 job started
- 4 job progress (one per company)
- 4 transaction starts (one per company)
- 3 transaction success (companies 1, 2, 4)
- 1 transaction error (company 3)
- 1 batch item error (company 3)
- 1 job completed
- 1 application finish
"""

import sys
import os
from pathlib import Path

# Add the src directory to the path so we can import our logger
src_path = Path(__file__).parent.parent.parent.parent / 'src'
sys.path.insert(0, str(src_path))

# Load environment variables from .env file
from dotenv import load_dotenv
load_dotenv()

import requests
from logger import (
    SOVDEV_LOGLEVELS,
    sovdev_initialize,
    sovdev_log,
    sovdev_log_job_status,
    sovdev_log_job_progress,
    sovdev_start_span,
    sovdev_end_span,
    sovdev_shutdown,
    create_peer_services,
)


# =============================================================================
# PEER SERVICES CONFIGURATION
# =============================================================================

# Define peer services - INTERNAL is auto-generated
PEER_SERVICES = create_peer_services({
    'BRREG': 'SYS1234567'  # Norwegian company registry
})


# =============================================================================
# BUSINESS LOGIC
# =============================================================================

def fetch_company_data(org_number: str) -> dict:
    """
    Fetch company data from Norwegian company registry (BRREG).

    Args:
        org_number: Norwegian organization number

    Returns:
        Company data dictionary

    Raises:
        Exception: If company not found or API error
    """
    url = f'https://data.brreg.no/enhetsregisteret/api/enheter/{org_number}'
    response = requests.get(url, timeout=10)

    if response.status_code != 200:
        # Match typescript/test/e2e/company-lookup/company-lookup.ts's
        # `HTTP ${res.statusCode}: ${data}` exactly, including the response
        # body -- confirmed empty for this specific BRREG 404, same as
        # TypeScript's accumulated `data`, so this also matches its trailing
        # "HTTP 404: " (colon-space-nothing), not a coincidence to preserve.
        raise Exception(f'HTTP {response.status_code}: {response.text}')

    return response.json()


def lookup_company(org_number: str) -> None:
    """
    Look up a single company from BRREG.

    This function demonstrates transaction correlation using spans:
    - Creates a span for the entire operation
    - Logs transaction start
    - Makes HTTP request to BRREG
    - Logs transaction success or error
    - Ends span (marks as error if exception occurred)

    Args:
        org_number: Norwegian organization number
    """
    FUNCTIONNAME = 'lookupCompany'
    input_data = {'organisasjonsnummer': org_number}

    # Start span for this operation
    span = sovdev_start_span(FUNCTIONNAME, input_data)

    try:
        # Log transaction start
        sovdev_log(
            SOVDEV_LOGLEVELS.INFO,
            FUNCTIONNAME,
            f'Looking up company {org_number}',
            PEER_SERVICES.BRREG,
            input_json=input_data,
            response_json=None,
            exception=None
        )

        # Fetch company data from BRREG
        company_data = fetch_company_data(org_number)

        # Extract response data
        response = {
            'navn': company_data.get('navn'),
            'organisasjonsform': company_data.get('organisasjonsform', {}).get('beskrivelse')
        }

        # Log transaction success
        sovdev_log(
            SOVDEV_LOGLEVELS.INFO,
            FUNCTIONNAME,
            f'Company found: {response["navn"]}',
            PEER_SERVICES.BRREG,
            input_json=input_data,
            response_json=response,
            exception=None
        )

        # End span on success
        sovdev_end_span(span)

    except Exception as error:
        # Log transaction error
        sovdev_log(
            SOVDEV_LOGLEVELS.ERROR,
            FUNCTIONNAME,
            f'Failed to lookup company {org_number}',
            PEER_SERVICES.BRREG,
            input_json=input_data,
            response_json=None,
            exception=error
        )

        # End span with error
        sovdev_end_span(span, error)

        # Re-raise so batch can handle it
        raise


def batch_lookup(org_numbers: list) -> None:
    """
    Process multiple companies in a batch job.

    This function demonstrates:
    - Job status tracking (started/completed)
    - Job progress tracking (X of Y)
    - Error handling in batch context
    - Success rate calculation

    Args:
        org_numbers: List of Norwegian organization numbers
    """
    JOB_NAME = 'CompanyLookupBatch'
    FUNCTIONNAME = 'batchLookup'

    # Log job started
    sovdev_log_job_status(
        SOVDEV_LOGLEVELS.INFO,
        FUNCTIONNAME,
        JOB_NAME,
        'Started',
        PEER_SERVICES.INTERNAL,
        input_json={'totalCompanies': len(org_numbers)}
    )

    # Process each company
    successful = 0
    failed = 0

    for i, org_number in enumerate(org_numbers):
        # Log progress
        sovdev_log_job_progress(
            SOVDEV_LOGLEVELS.INFO,
            FUNCTIONNAME,
            org_number,
            i + 1,
            len(org_numbers),
            PEER_SERVICES.BRREG,
            input_json={'organisasjonsnummer': org_number}
        )

        # Try to lookup company
        try:
            lookup_company(org_number)
            successful += 1
        except Exception as error:
            failed += 1
            # Log batch item error
            sovdev_log(
                SOVDEV_LOGLEVELS.ERROR,
                FUNCTIONNAME,
                f'Batch item {i + 1} failed',
                PEER_SERVICES.BRREG,
                input_json={'organisasjonsnummer': org_number, 'itemNumber': i + 1},
                response_json=None,
                exception=error
            )

    # Log job completed
    success_rate = f'{round((successful / len(org_numbers)) * 100)}%'
    sovdev_log_job_status(
        SOVDEV_LOGLEVELS.INFO,
        FUNCTIONNAME,
        JOB_NAME,
        'Completed',
        PEER_SERVICES.INTERNAL,
        input_json={
            'totalCompanies': len(org_numbers),
            'successful': successful,
            'failed': failed,
            'successRate': success_rate
        }
    )


# =============================================================================
# MAIN PROGRAM
# =============================================================================

def main() -> None:
    """
    Main program entry point.

    Demonstrates complete usage of sovdev-logger:
    1. Initialize logger
    2. Log application start
    3. Run batch job
    4. Log application finish
    5. Flush telemetry
    """
    # 1. Initialize logger
    service_name = os.environ.get('OTEL_SERVICE_NAME', 'sovdev-test-company-lookup-python')
    service_version = '1.0.0'

    sovdev_initialize(
        service_name,
        service_version,
        PEER_SERVICES.mappings
    )

    # 2. Log application start
    sovdev_log(
        SOVDEV_LOGLEVELS.INFO,
        'main',
        'Company Lookup Service started',
        PEER_SERVICES.INTERNAL
    )

    # 3. Run batch job
    # Use exact test data as specified in 08-testprogram-company-lookup.md
    companies = [
        '971277882',  # Company 1: DIREKTORATET FOR UTVIKLINGSSAMARBEID (NORAD) - Valid
        '915933149',  # Company 2: DIREKTORATET FOR E-HELSE MELDT TIL OPPHØR - Valid
        '974652846',  # Company 3: INVALID - Will fail with HTTP 404 (intentional)
        '916201478'   # Company 4: KVISTADMANNEN AS - Valid
    ]

    batch_lookup(companies)

    # 4. Log application finish
    sovdev_log(
        SOVDEV_LOGLEVELS.INFO,
        'main',
        'Company Lookup Service finished',
        PEER_SERVICES.INTERNAL
    )

    # 5. Shut down telemetry (flushes, then permanently shuts down the SDK —
    #    call this once, at the true end, not sovdev_flush() which is safe
    #    to call repeatedly but never shuts anything down)
    print('\n🔄 Shutting down telemetry...')
    sovdev_shutdown()
    print('✅ Telemetry shut down\n')


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print('\n⚠️  Interrupted by user')
        sovdev_shutdown()
        sys.exit(1)
    except Exception as e:
        print(f'\n❌ Fatal error: {e}')
        sovdev_shutdown()
        sys.exit(1)
