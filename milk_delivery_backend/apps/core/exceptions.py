import logging
from rest_framework.views import exception_handler
from rest_framework.response import Response
from rest_framework import status

logger = logging.getLogger("django.request")

def custom_exception_handler(exc, context):
    """
    Standardized production-grade DRF exception handler.
    Wraps all error responses in a consistent JSON payload:
    {
        "status": "error",
        "code": "ERROR_CODE",
        "message": "Human readable summary",
        "errors": { ... }
    }
    """
    response = exception_handler(exc, context)

    if response is not None:
        view = context.get("view")
        view_name = view.__class__.__name__ if view else "UnknownView"

        error_data = response.data
        message = "An error occurred during request processing."

        if isinstance(error_data, dict):
            if "detail" in error_data:
                message = str(error_data["detail"])
            elif len(error_data) > 0:
                first_key = list(error_data.keys())[0]
                first_val = error_data[first_key]
                if isinstance(first_val, list) and len(first_val) > 0:
                    message = f"{first_key}: {first_val[0]}"
                else:
                    message = f"{first_key}: {first_val}"
        elif isinstance(error_data, list) and len(error_data) > 0:
            message = str(error_data[0])

        code = "VALIDATION_ERROR"
        if response.status_code == 401:
            code = "UNAUTHORIZED"
        elif response.status_code == 403:
            code = "FORBIDDEN"
        elif response.status_code == 404:
            code = "NOT_FOUND"
        elif response.status_code == 429:
            code = "RATE_LIMITED"
        elif response.status_code >= 500:
            code = "SERVER_ERROR"

        response.data = {
            "status": "error",
            "code": code,
            "message": message,
            "errors": error_data,
        }
    else:
        # Unhandled 500 server exceptions
        logger.error(f"Unhandled Exception in {context.get('view')}: {str(exc)}", exc_info=True)
        response = Response(
            {
                "status": "error",
                "code": "INTERNAL_SERVER_ERROR",
                "message": "An internal server error occurred. Our engineering team has been notified.",
                "errors": {},
            },
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    return response
