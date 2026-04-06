import { useState, useEffect } from 'react';
import { api } from '../api';
import type { ExchangeRate, Invoice, InvoiceStatus, FeePriority } from '../types';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Heart, Coffee, Gift, Loader2, Copy, CheckCircle2, AlertCircle } from 'lucide-react';

export function DonatePage() {
    const [exchangeRate, setExchangeRate] = useState<ExchangeRate | null>(null);
    const [rateError, setRateError] = useState('');
    const [invoices, setInvoices] = useState<InvoiceStatus[]>([]);
    const [selectedAmount, setSelectedAmount] = useState<number | null>(null);
    const [selectedPriority, setSelectedPriority] = useState<FeePriority>('normal');
    const [customAmount, setCustomAmount] = useState('');
    const [customXmrAmount, setCustomXmrAmount] = useState('');
    const [isLoadingRate, setIsLoadingRate] = useState(true);
    const [isLoadingInvoice, setIsLoadingInvoice] = useState(false);
    const [createdInvoice, setCreatedInvoice] = useState<Invoice | null>(null);
    const [copiedAddress, setCopiedAddress] = useState(false);
    const [error, setError] = useState('');

    useEffect(() => {
        loadExchangeRate();
        loadInvoices();
    }, []);

    const loadExchangeRate = async () => {
        try {
            setIsLoadingRate(true);
            setRateError('');
            const rate = await api.getExchangeRate();
            setExchangeRate(rate);
        } catch (err) {
            console.error('Failed to load exchange rate:', err);
            const errorMsg = err instanceof Error ? err.message : 'Failed to load exchange rate';
            setRateError(errorMsg);
        } finally {
            setIsLoadingRate(false);
        }
    };

    const loadInvoices = async () => {
        try {
            const response = await api.getInvoices();
            setInvoices(response?.invoices || []);
        } catch (err) {
            console.error('Failed to load invoices:', err);
            setInvoices([]);
        }
    };

    const handleCreateInvoice = async () => {
        setError('');

        if (!exchangeRate?.xmr_usd) {
            const xmrAmount = parseFloat(customXmrAmount);
            if (isNaN(xmrAmount) || xmrAmount <= 0) {
                setError('Please enter a valid XMR amount');
                return;
            }

            try {
                setIsLoadingInvoice(true);
                const invoice = await api.createInvoice({
                    xmr_amount: xmrAmount,
                    priority: selectedPriority
                });
                setCreatedInvoice(invoice);
                await loadInvoices();
            } catch (err) {
                setError(err instanceof Error ? err.message : 'Failed to create invoice');
            } finally {
                setIsLoadingInvoice(false);
            }
            return;
        }

        const amount = selectedAmount || parseFloat(customAmount);
        if (isNaN(amount) || amount <= 0) {
            setError('Please select or enter a valid amount');
            return;
        }

        try {
            setIsLoadingInvoice(true);
            const invoice = await api.createInvoice({
                amount,
                currency: 'USD',
                priority: selectedPriority
            });
            setCreatedInvoice(invoice);
            await loadInvoices();
        } catch (err) {
            setError(err instanceof Error ? err.message : 'Failed to create invoice');
        } finally {
            setIsLoadingInvoice(false);
        }
    };

    const copyToClipboard = (text: string) => {
        navigator.clipboard.writeText(text);
        setCopiedAddress(true);
        setTimeout(() => setCopiedAddress(false), 2000);
    };

    const formatXmr = (xmr: number) => {
        return xmr.toFixed(12);
    };

    const formatUsd = (usd: number) => {
        return usd.toFixed(2);
    };

    const presetAmounts = [5, 10, 25, 50];
    const priorityOptions: { value: FeePriority; label: string; description: string }[] = [
        { value: 'slow', label: 'Slow', description: '~90 min' },
        { value: 'normal', label: 'Normal', description: '~30 min' },
        { value: 'fast', label: 'Fast', description: '~10 min' },
        { value: 'fastest', label: 'Fastest', description: '~5 min' }
    ];

    const getEstimatedFee = () => {
        try {
            if (!exchangeRate || !exchangeRate.fees || !exchangeRate.fees[selectedPriority]) {
                return { usd: 0, xmr: 0, minutes: 30 };
            }
            const fee = exchangeRate.fees[selectedPriority];
            return {
                usd: fee?.estimated_tx_fee_usd || 0,
                xmr: fee?.estimated_tx_fee_xmr || 0,
                minutes: fee?.estimated_minutes || 30
            };
        } catch {
            return { usd: 0, xmr: 0, minutes: 30 };
        }
    };

    const fee = getEstimatedFee();

    return (
        <div className="max-w-2xl mx-auto p-4">
            <h1 className="text-2xl font-bold mb-6">Support Xeetapus</h1>
            
            {error && (
                <div className="mb-4 p-4 bg-red-100 text-red-800 rounded-lg flex items-start gap-2">
                    <AlertCircle className="w-5 h-5 mt-0.5 flex-shrink-0" />
                    <span>{error}</span>
                </div>
            )}

            <Card className="mb-6">
                <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                        <Heart className="w-5 h-5 text-red-500" />
                        Why Donate?
                    </CardTitle>
                </CardHeader>
                <CardContent>
                    <p className="text-muted-foreground">
                        Xeetapus is an independent, ad-free platform. Your donations help cover server costs 
                        and support ongoing development. Every contribution, no matter the size, helps keep 
                        the platform running and improving.
                    </p>
                    <p className="text-sm text-muted-foreground mt-2">
                        Payments are processed via Monero (XMR) for privacy and low fees.
                    </p>
                </CardContent>
            </Card>

            {rateError && (
                <div className="mb-4 p-4 bg-yellow-100 text-yellow-800 rounded-lg flex items-start gap-2">
                    <AlertCircle className="w-5 h-5 mt-0.5 flex-shrink-0" />
                    <div>
                        <p className="font-medium">Exchange Rate Unavailable</p>
                        <p className="text-sm mt-1">{rateError}</p>
                        <p className="text-sm mt-1">You can still donate by specifying XMR directly below.</p>
                    </div>
                </div>
            )}

            {isLoadingRate ? (
                <div className="text-center py-12">Loading...</div>
            ) : (
                <>
                    <Card className="mb-6">
                        <CardHeader>
                            <CardTitle className="flex items-center gap-2">
                                <Coffee className="w-5 h-5" />
                                {exchangeRate?.xmr_usd ? 'Select Amount' : 'Enter XMR Amount'}
                            </CardTitle>
                        </CardHeader>
                        <CardContent className="space-y-4">
{exchangeRate?.xmr_usd ? (
                                 <>
                                    <div>
                                        <label className="text-sm font-medium mb-2 block">Amount (USD)</label>
                                        <div className="flex flex-wrap gap-2 mb-3">
                                            {Array.isArray(presetAmounts) && presetAmounts.map(amount => (
                                                <Button
                                                    key={amount}
                                                    variant={selectedAmount === amount ? 'default' : 'outline'}
                                                    onClick={() => {
                                                        setSelectedAmount(amount);
                                                        setCustomAmount('');
                                                    }}
                                                >
                                                    ${amount}
                                                </Button>
                                            ))}
                                        </div>
                                        <div className="flex gap-2">
                                            <Input
                                                type="number"
                                                placeholder="Custom amount"
                                                value={customAmount}
                                                onChange={(e) => {
                                                    setCustomAmount(e.target.value);
                                                    setSelectedAmount(null);
                                                }}
                                                min="1"
                                                step="0.01"
                                            />
                                        </div>
                                    </div>

                                    <div>
                                        <label className="text-sm font-medium mb-2 block">Transaction Priority</label>
                                        <div className="flex flex-wrap gap-2">
                                            {Array.isArray(priorityOptions) && priorityOptions.map(option => (
                                                <Button
                                                    key={option.value}
                                                    variant={selectedPriority === option.value ? 'default' : 'outline'}
                                                    size="sm"
                                                    onClick={() => setSelectedPriority(option.value)}
                                                >
                                                    {option.label} ({option.description})
                                                </Button>
                                            ))}
                                        </div>
                                    </div>

                                    {(selectedAmount || customAmount) && !isNaN(selectedAmount || parseFloat(customAmount) || 0) && (
                                        <div className="space-y-2 p-3 bg-muted rounded-lg">
                                            <p className="text-sm">
                                                <span className="font-medium">Amount:</span> ${(selectedAmount || parseFloat(customAmount)).toFixed(2)} USD
                                            </p>
                                            <p className="text-sm">
                                                <span className="font-medium">Estimated XMR:</span> {
                                                    exchangeRate?.xmr_usd ? formatXmr((selectedAmount || parseFloat(customAmount)) / exchangeRate.xmr_usd) : 'N/A'
                                                }
                                            </p>
                                            <p className="text-sm">
                                                <span className="font-medium">Network Fee:</span> {
                                                    formatUsd(fee.usd)
                                                } USD ({formatXmr(fee.xmr)} XMR)
                                            </p>
                                            <p className="text-sm font-medium">
                                                Total: {
                                                    formatUsd((selectedAmount || parseFloat(customAmount)) + fee.usd)
                                                } USD
                                            </p>
                                            <p className="text-xs text-muted-foreground">
                                                Estimated confirmation: {fee.minutes} minutes
                                            </p>
                                        </div>
                                    )}
                                </>
                            ) : (
                                <>
                                    <div>
                                        <label className="text-sm font-medium mb-2 block">Amount (XMR)</label>
                                        <Input
                                            type="number"
                                            placeholder="Enter XMR amount"
                                            value={customXmrAmount}
                                            onChange={(e) => setCustomXmrAmount(e.target.value)}
                                            min="0.000000000001"
                                            step="0.000000000001"
                                        />
                                        <p className="text-xs text-muted-foreground mt-1">
                                            Enter the amount of Monero you wish to donate.
                                        </p>
                                    </div>

                                    <div>
                                        <label className="text-sm font-medium mb-2 block">Transaction Priority</label>
                                        <div className="flex flex-wrap gap-2">
                                            {Array.isArray(priorityOptions) && priorityOptions.map(option => (
                                                <Button
                                                    key={option.value}
                                                    variant={selectedPriority === option.value ? 'default' : 'outline'}
                                                    size="sm"
                                                    onClick={() => setSelectedPriority(option.value)}
                                                >
                                                    {option.label} ({option.description})
                                                </Button>
                                            ))}
                                        </div>
                                    </div>

                                    {customXmrAmount && !isNaN(parseFloat(customXmrAmount)) && parseFloat(customXmrAmount) > 0 && (
                                        <div className="space-y-2 p-3 bg-muted rounded-lg">
                                            <p className="text-sm">
                                                <span className="font-medium">Amount:</span> {formatXmr(parseFloat(customXmrAmount))} XMR
                                            </p>
                                            <p className="text-sm">
                                                <span className="font-medium">Network Fee:</span> {formatXmr(fee.xmr)} XMR
                                            </p>
                                            <p className="text-sm font-medium">
                                                Total: {formatXmr(parseFloat(customXmrAmount) + fee.xmr)} XMR
                                            </p>
                                            <p className="text-xs text-muted-foreground">
                                                Estimated confirmation: {fee.minutes} minutes
                                            </p>
                                        </div>
                                    )}
                                </>
                            )}

                            <Button 
                                onClick={handleCreateInvoice}
                                disabled={
                                    isLoadingInvoice || 
                                    (exchangeRate?.xmr_usd && !selectedAmount && !customAmount) ||
                                    (!exchangeRate?.xmr_usd && !customXmrAmount)
                                }
                                className="w-full"
                            >
                                {isLoadingInvoice && <Loader2 className="w-4 h-4 animate-spin mr-2" />}
                                Create Invoice
                            </Button>
                        </CardContent>
                    </Card>

                    {createdInvoice && (
                        <Card className="mb-6 border-green-500">
                            <CardHeader>
                                <CardTitle className="flex items-center gap-2 text-green-700">
                                    <CheckCircle2 className="w-5 h-5" />
                                    Invoice Created
                                </CardTitle>
                            </CardHeader>
                            <CardContent className="space-y-4">
                                <div className="bg-muted p-3 rounded-lg">
                                    <p className="text-sm font-medium mb-2">Send Monero to:</p>
                                    <div className="flex gap-2">
                                        <code className="flex-1 text-xs break-all bg-background p-2 rounded">
                                            {createdInvoice.address}
                                        </code>
                                        <Button
                                            size="sm"
                                            variant="outline"
                                            onClick={() => copyToClipboard(createdInvoice.address)}
                                        >
                                            {copiedAddress ? <CheckCircle2 className="w-4 h-4" /> : <Copy className="w-4 h-4" />}
                                        </Button>
                                    </div>
                                </div>
                                <div className="space-y-1 text-sm">
                                    <p><span className="font-medium">Amount:</span> {formatXmr(createdInvoice.xmr_amount)} XMR</p>
                                    <p><span className="font-medium">Network Fee:</span> {formatXmr(createdInvoice.network_fee)} XMR</p>
                                    <p><span className="font-medium">Total:</span> {formatXmr(createdInvoice.total_xmr)} XMR</p>
                                    {createdInvoice.fiat_amount !== undefined && (
                                        <><p><span className="font-medium">USD Value:</span> ${formatUsd(createdInvoice.fiat_amount)}</p></>
                                    )}
                                    <p><span className="font-medium">Estimated Time:</span> ~{createdInvoice.estimated_minutes} minutes</p>
                                </div>
                                <p className="text-xs text-muted-foreground">
                                    Send the exact amount. The payment will be confirmed after network confirmation.
                                </p>
                            </CardContent>
                        </Card>
                    )}

                    {Array.isArray(invoices) && invoices.length > 0 && (
                        <Card>
                            <CardHeader>
                                <CardTitle className="flex items-center gap-2">
                                    <Gift className="w-5 h-5" />
                                    Your Invoices
                                </CardTitle>
                            </CardHeader>
                            <CardContent>
                                <div className="space-y-3">
                                    {invoices.map(invoice => (
                                        <div 
                                            key={invoice.id}
                                            className="flex justify-between items-center p-3 bg-muted rounded"
                                        >
                                            <div>
                                                <p className="font-medium">Invoice #{invoice.id}</p>
                                                <p className="text-sm text-muted-foreground">
                                                    {new Date(invoice.created_at).toLocaleDateString()}
                                                </p>
                                            </div>
                                            <div className="text-right">
                                                <p className="font-medium">{invoice.status}</p>
                                                {invoice.paid_at && (
                                                    <p className="text-xs text-muted-foreground">
                                                        Paid: {new Date(invoice.paid_at).toLocaleDateString()}
                                                    </p>
                                                )}
                                            </div>
                                        </div>
                                    ))}
                                </div>
                            </CardContent>
                        </Card>
                    )}
                </>
            )}

            <div className="text-center text-sm text-muted-foreground mt-6">
                {exchangeRate?.xmr_usd ? (
                    <p>Current XMR price: ${formatUsd(exchangeRate.xmr_usd)}</p>
                ) : rateError ? (
                    <p>Exchange rate unavailable</p>
                ) : null}
                <p className="mt-2">Thank you for your support!</p>
            </div>
        </div>
    );
}