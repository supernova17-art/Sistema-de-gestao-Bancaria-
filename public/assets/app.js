document.addEventListener('submit', (event) => {
  const form = event.target.closest('[data-confirm]');
  if (form && !window.confirm(form.dataset.confirm)) event.preventDefault();
});

document.querySelectorAll('input[type="number"][name="amount"]').forEach((input) => {
  input.min = '0.01';
  input.step = '0.01';
});
