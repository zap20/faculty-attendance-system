<?php
/**
 * Validator Helper
 * Input validation utilities
 */

class Validator {
    private $errors = [];
    private $data = [];

    public function __construct(array $data) {
        $this->data = $data;
    }

    public function required(string $field, string $label = null): self {
        $label = $label ?? $field;
        if (!isset($this->data[$field]) || trim($this->data[$field]) === '') {
            $this->errors[$field] = "$label is required";
        }
        return $this;
    }

    public function email(string $field, string $label = null): self {
        $label = $label ?? $field;
        if (isset($this->data[$field]) && !filter_var($this->data[$field], FILTER_VALIDATE_EMAIL)) {
            $this->errors[$field] = "$label must be a valid email";
        }
        return $this;
    }

    public function minLength(string $field, int $min, string $label = null): self {
        $label = $label ?? $field;
        if (isset($this->data[$field]) && strlen($this->data[$field]) < $min) {
            $this->errors[$field] = "$label must be at least $min characters";
        }
        return $this;
    }

    public function maxLength(string $field, int $max, string $label = null): self {
        $label = $label ?? $field;
        if (isset($this->data[$field]) && strlen($this->data[$field]) > $max) {
            $this->errors[$field] = "$label must not exceed $max characters";
        }
        return $this;
    }

    public function numeric(string $field, string $label = null): self {
        $label = $label ?? $field;
        if (isset($this->data[$field]) && !is_numeric($this->data[$field])) {
            $this->errors[$field] = "$label must be a number";
        }
        return $this;
    }

    public function integer(string $field, string $label = null): self {
        $label = $label ?? $field;
        if (isset($this->data[$field]) && !filter_var($this->data[$field], FILTER_VALIDATE_INT)) {
            $this->errors[$field] = "$label must be an integer";
        }
        return $this;
    }

    public function inArray(string $field, array $allowed, string $label = null): self {
        $label = $label ?? $field;
        if (isset($this->data[$field]) && !in_array($this->data[$field], $allowed)) {
            $this->errors[$field] = "$label must be one of: " . implode(', ', $allowed);
        }
        return $this;
    }

    public function date(string $field, string $format = 'Y-m-d', string $label = null): self {
        $label = $label ?? $field;
        if (isset($this->data[$field])) {
            $d = DateTime::createFromFormat($format, $this->data[$field]);
            if (!$d || $d->format($format) !== $this->data[$field]) {
                $this->errors[$field] = "$label must be a valid date ($format)";
            }
        }
        return $this;
    }

    public function time(string $field, string $label = null): self {
        $label = $label ?? $field;
        if (isset($this->data[$field])) {
            $pattern = '/^([01]?[0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$/';
            if (!preg_match($pattern, $this->data[$field])) {
                $this->errors[$field] = "$label must be a valid time (HH:MM or HH:MM:SS)";
            }
        }
        return $this;
    }

    public function hasErrors(): bool {
        return !empty($this->errors);
    }

    public function getErrors(): array {
        return $this->errors;
    }

    public function validate(): void {
        if ($this->hasErrors()) {
            Response::validationError($this->errors);
        }
    }

    public function getValue(string $field, $default = null) {
        return $this->data[$field] ?? $default;
    }

    public function getAll(): array {
        return $this->data;
    }
}
