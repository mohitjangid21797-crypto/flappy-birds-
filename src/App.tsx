import { useState } from 'react';

interface HomePageProps {
  title: string;
}

function HomePage({ title }: HomePageProps) {
  const [counter, setCounter] = useState<number>(0);

  const incrementCounter = () => {
    setCounter((prev) => prev + 1);
  };

  return (
    <div className="min-h-screen flex flex-col bg-[#FEF7FF] text-[#1D1B20] antialiased selection:bg-[#EADDFF] selection:text-[#21005D]">
      <header className="h-16 px-4 bg-[#CFBCFF] flex items-center shrink-0">
        <h1 className="text-[22px] leading-7 font-normal text-[#1D1B20] truncate">
          {title}
        </h1>
      </header>

      <main className="flex-1 flex items-center justify-center px-4">
        <div className="flex flex-col items-center justify-center text-center">
          <p className="text-sm leading-5 font-normal text-[#1D1B20]">
            You have pushed the button this many times:
          </p>
          <p
            className="text-[28px] leading-9 font-normal text-[#1D1B20] tabular-nums mt-0.5"
            aria-live="polite"
          >
            {counter}
          </p>
        </div>
      </main>

      <button
        type="button"
        onClick={incrementCounter}
        title="Increment"
        aria-label="Increment"
        className="fixed bottom-4 right-4 w-14 h-14 rounded-2xl bg-[#EADDFF] hover:bg-[#E2D2FC] active:bg-[#D6C2FA] text-[#21005D] shadow-[0_4px_8px_3px_rgba(0,0,0,0.15),0_1px_3px_rgba(0,0,0,0.3)] flex items-center justify-center transition-colors duration-150 cursor-pointer focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#6750A4]"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="currentColor"
          className="w-6 h-6"
          aria-hidden="true"
        >
          <path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z" />
        </svg>
      </button>
    </div>
  );
}

export function App() {
  return <HomePage title="Flutter Demo Home Page" />;
}

export default App;
